class CommentsController < ApplicationController
  before_action :require_user, except: :index

  def index
    render json: comments.map { |comment| comment_json(comment) }
  end

  def create
    comment = Comment.create!(comment_params)
    render json: comment_json(comment)
  end

  def destroy
    comment = comments.where(author: current_user, id: params[:id]).first
    status =
      if comment
        comment.destroy
        :ok
      else
        :unauthorized
      end
    render nothing: true, status: status
  end

  private

  def comments
    Comment
      .where(commentable: commentable)
      .includes(:author, :parent)
  end

  def comment_json(comment)
    {
      id: comment.id,
      parent_id: comment.parent,
      text: comment.text,
      subject_url: url_for(commentable),
      author: {
        name: comment.author.name,
        url: url_for(comment.author)
      },
      created_at: comment.created_at.iso8601,
    }
  end

  def commentable
    @commentable ||= commentable_type.find(commentable_id)
  end

  def commentable_type
    request.path.split('/').second.singularize.camelize.constantize
  end

  def commentable_id
    request.path.split('/').third.to_i
  end

  def comment_params
    params.permit(:text).merge(
      author: current_user,
      commentable: commentable
    )
  end
end
