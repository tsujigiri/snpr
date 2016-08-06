class PhenotypesController < ApplicationController
  before_filter :require_user, only: %i(new create get_genotypes recommend_phenotype)
  helper_method :sort_column, :sort_direction

  def index
    @title = 'Listing all phenotypes'
    @phenotypes = Phenotype
      .with_number_of_users
      .order("#{sort_column} #{sort_direction}")
      .includes(:user_phenotypes)

    @phenotypes_paginate = @phenotypes.paginate(page: params[:page], per_page: 10)

    respond_to do |format|
      format.html
      format.xml 
      format.json do
        phenotypes_json =
          @phenotypes.find_each.map do |p|
            {
              id: p.id,
              characteristic: p.characteristic,
              known_variations: p.known_phenotypes,
              number_of_users: p.number_of_users
            }
          end
        render :json => phenotypes_json
      end
    end
  end

  def new
    @phenotype = Phenotype.new
    @user_phenotype = UserPhenotype.new
    @title = "Create a new phenotype"

    # Make list of phenotypes for autocomplete
    @phenotype_list = Phenotype.pluck(:characteristic).to_json

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create
    @phenotype = Phenotype.find_or_initialize_by(phenotype_params.slice(:characteristic)) do |p|
      p.assign_attributes(phenotype_params)
    end
    new_phenotype = @phenotype.new_record?
    @phenotype.user_phenotypes_attributes = user_phenotype_params

    if @phenotype.save
      if new_phenotype
        current_user.phenotype_creation_counter += 1
        current_user.save!

        check_and_award_new_phenotypes(1, 'Created a new phenotype')
        check_and_award_new_phenotypes(5, 'Created 5 new phenotypes')
        check_and_award_new_phenotypes(10, 'Created 10 new phenotypes')

        Mailnewphenotype.perform_async(@phenotype.id, current_user.id)
      end

      # check for additional phenotype awards
      check_and_award_additional_phenotypes(1, 'Entered first phenotype')
      check_and_award_additional_phenotypes(5, 'Entered 5 additional phenotypes')
      check_and_award_additional_phenotypes(10, 'Entered 10 additional phenotypes')
      check_and_award_additional_phenotypes(20, 'Entered 20 additional phenotypes')
      check_and_award_additional_phenotypes(50, 'Entered 50 additional phenotypes')
      check_and_award_additional_phenotypes(100, 'Entered 100 additional phenotypes')

      flash[:notice] = 'Phenotype successfully created.'

      redirect_to current_user
    else
      render :new
    end
  end

  def show
    @phenotype = Phenotype.find(params[:id]) || not_found
    @comments = PhenotypeComment
      .where(phenotype_id: params[:id])
      .order('created_at ASC')
    @phenotype_comment = PhenotypeComment.new
    @user_phenotype = UserPhenotype.new

    recommender = PhenotypeRecommender.new
    similar_ids = recommender.for(params[:id])
    # For some reason, Recommendify sometimes returns items of class Fixnum, sometimes of class Recommendify
    if similar_ids[0].class == Fixnum
      @similar_phenotypes = Phenotype.where(['id in (?)', similar_ids]).limit(6)
    else
      @similar_phenotypes = Phenotype.where(['id in (?)', similar_ids.map { |rec| rec.item_id } ]).limit(6)
    end
  end

  def recommend_phenotype
    # init the recommendation-engines
    @phenotype_recommender = PhenotypeRecommender.new
    @variation_recommender = VariationRecommender.new

    # get up to three similar phenotypes regardless of variation

    @similar_ids = @phenotype_recommender.for(params[:id])
    @similar_phenotypes = []
    @item_counter = 0

    @similar_ids.each do |s|
      if @item_counter < 3
        @phenotype = Phenotype.find(s.item_id)
        if current_user.phenotypes.include?(@phenotype) == false
          @similar_phenotypes << @phenotype
          @item_counter += 1
        end
      else
        break
      end
    end

    # get up to three similar combinations of phenotype and variation
    @user_phenotype = UserPhenotype.find_by_phenotype_id_and_user_id(params[:id],current_user.id)
    if @user_phenotype != nil
      @users_variation = @user_phenotype.variation
      @variation_recommend_request = params[:id]+"=>"+@users_variation
    else
      @variation_recommend_request = ""
    end

    @similar_combinations = @phenotype_recommender.for(@variation_recommend_request)
    @similar_variations = []
    @combination_counter = 0

    @similar_combinations.each do |s|
      if @combination_counter < 3
        @phenotype = Phenotype.find_by_id(s.item_id.split("=>")[0])
        if current_user.phenotypes.include?(@phenotype) == false
          @similar_variations << s
          @combination_counter += 1
        end
      else
        break
      end
    end

    @phenotype = Phenotype.find_by_id(params[:id])

    if @similar_phenotypes == [] and @similar_variations == []
      redirect_to :action => "index"
    else  
      respond_to do |format|
        format.html
      end
    end
  end

  def feed
    @phenotype = Phenotype.find(params[:id])
    @user_phenotypes = @phenotype.user_phenotypes
    @genotypes = []
    @user_phenotypes.each do |up|
      if up.user.genotypes[0] != nil
        @genotypes << up.user.genotypes[0]
      end
    end

    @genotypes.sort!{ |b,a| a.created_at <=> b.created_at }

    render :action => "rss", :layout => false
  end

  def get_genotypes
    Sidekiq::Client.enqueue(Zipgenotypingfiles, params[:id],
                            params[:variation], current_user.email)
    @phenotype = Phenotype.find(params[:id])
    @variation = params[:variation]
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def json_variation
    @result = {}
    begin
      @phenotype = Phenotype.find_by_id(params[:phenotype_id])
      @result["id"] = @phenotype.id
      @result["characteristic"] = @phenotype.characteristic
      @result["description"] = @phenotype.description
      @result["known_variations"] = @phenotype.known_phenotypes
      @result["users"] = []
      @phenotype.user_phenotypes.each do |up|
        @user_phenotype = {"user_id" => up.user_id,"variation" => up.variation}
        @result["users"] << @user_phenotype
      end
    rescue
      @result["error"] = "Sorry, this phenotype doesn't exist"
    end

    respond_to do |format|
      format.json { render :json => @result } 
    end    

  end

  def json
    if params[:user_id].index(",")
      @user_ids = params[:user_id].split(",")
      @results = []
      @user_ids.each do |id|
        @new_param = {}
        @new_param[:user_id] = id
        @results << json_element(@new_param)
      end

    elsif params[:user_id].index("-")
      @results = []
      @id_array = params[:user_id].split("-")
      @user_ids = (@id_array[0].to_i..@id_array[1].to_i).to_a
      @user_ids.each do |id|
        @new_param = {}
        @new_param[:user_id] = id
        @results << json_element(@new_param)
      end

    else 
      @results = json_element(params)	  
    end   

    respond_to do |format|
      format.json { render :json => @results } 
    end
  end

  def json_element(params)
    begin
      @user = User.find_by_id(params[:user_id])
      @result = {}
      @user_phenotypes = UserPhenotype.where(user_id: @user.id)

      @result["user"] = {}
      @result["user"]["name"] = @user.name
      @result["user"]["id"] = @user.id

      @phenotype_hash = {}

      @user_phenotypes.each do |up|
        @phenotype_hash[up.phenotype.characteristic] = {}
        @phenotype_hash[up.phenotype.characteristic]["phenotype_id"] = up.phenotype.id
        @phenotype_hash[up.phenotype.characteristic]["variation"] = up.variation
      end

      @result["phenotypes"] = @phenotype_hash
    rescue
      @result = {}
      @result["error"] = "Sorry, we couldn't find any information for this user"
    end
    return @result
  end

  private

  def sort_column
    Phenotype.column_names.include?(params[:sort]) ? params[:sort] : "number_of_users"
  end

  private

  def sort_column
    Phenotype.column_names.include?(params[:sort]) ? params[:sort] : "number_of_users"
  end

  def sort_direction
    %w[desc asc].include?(params[:direction]) ? params[:direction] : "desc"
  end

  def check_and_award_new_phenotypes(amount, achievement_string)
    @achievement = Achievement.find_by_award(achievement_string)
    if current_user.phenotype_creation_counter >= amount and UserAchievement.find_by_achievement_id_and_user_id(@achievement.id,current_user.id) == nil

      UserAchievement.create(:achievement_id => @achievement.id, :user_id => current_user.id)
      flash[:achievement] = %(Congratulations! You've unlocked an achievement: <a href="#{url_for(@achievement)}">#{@achievement.award}</a>).html_safe
    end
  end

  def check_and_award_additional_phenotypes(amount, achievement_string)
    @achievement = Achievement.find_by_award(achievement_string)
    if current_user.phenotype_count >= amount and UserAchievement.find_by_achievement_id_and_user_id(@achievement.id,current_user.id) == nil
      UserAchievement.create(:user_id => current_user.id, :achievement_id => @achievement.id)
      flash[:achievement] = %(Congratulations! You've unlocked an achievement: <a href="#{url_for(@achievement)}">#{@achievement.award}</a>).html_safe
    end
  end

  def phenotype_params
    params.require(:phenotype).permit(:description, :characteristic)
  end

  def user_phenotype_params
    params
      .require(:phenotype)
      .permit(user_phenotypes_attributes: [[:variation]])
      .require(:user_phenotypes_attributes)
      .values
      .map { |user_phenotype| user_phenotype.merge(user_id: current_user.id) }
  end
end
