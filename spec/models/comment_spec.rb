RSpec.describe Comment do
  it 'can have a parent' do
    parent = create(:comment)
    child = create(:comment, parent: parent)

    expect(Comment.count).to eq(2)
    expect(parent.children).to eq([child])
    expect(child.parent).to eq(parent)
  end

  it 'can comment on things' do
    snp = create(:snp)
    comment = create(:comment, commentable: snp)

    expect(comment.commentable).to eq(snp)
  end
end
