RSpec.describe 'Comments', :authenticated do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:snp) { create(:snp) }
  let!(:comment) do
    create(
      :comment,
      commentable: snp,
      author: user,
      text: 'Some comment'
    )
  end
  let(:other_comment) { create(:comment, commentable: comment, author: other_user) }

  describe 'GET /:commentable_type/:commentable_id/comments' do
    it 'returns all comments of a commentable' do
      get "/snps/#{snp.id}/comments.json"

      expect(JSON.parse(response.body)).to eq([
        {
          "id" => comment.id,
          "parent_id" => nil,
          "text" => 'Some comment',
          "subject_url" => snp_url(snp),
          "author" => { "name" => user.name, "url" => user_url(user) },
          "created_at" => comment.created_at.iso8601,
        }
      ])
    end
  end

  describe 'POST /:commentable_type/:commentable_id/comments' do
    before do
      create_user_session(user)
    end

    it 'creates a comment' do
      expect {
        post "/snps/#{snp.id}/comments.json", { text: 'A new comment' }
      }.to change(Comment, :count).by(1)

      expect(JSON.parse(response.body)).to include(
        'parent_id' => nil,
        'text' => 'A new comment',
        'subject_url' => snp_url(snp),
        'author' => {
          'name' => user.name,
          'url' => user_url(user),
        },
      )
    end
  end

  describe 'DELETE /:commentable_type/:commentable_id/comments/:id' do
    before do
      create_user_session(user)
    end

    it 'deletes a comment' do
      expect {
        delete "/snps/#{snp.id}/comments/#{comment.id}.json"
      }.to change(Comment, :count).by(-1)
    end

    it "does not delete other user's comments" do
      other_comment
      expect {
        delete "/snps/#{snp.id}/comments/#{other_comment.id}.json"
      }.to_not change(Comment, :count)

      expect(response.status).to eq(401)
    end
  end
end
