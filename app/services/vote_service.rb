class VoteService
  def self.create(vote:, actor:)
    vote.author = actor
    return false unless vote.valid?
    actor.ability.authorize! :create, vote
    vote.save!
    event = Events::NewVote.publish!(vote)
    DiscussionReader.for(discussion: vote.discussion, user: actor).viewed!(vote.created_at + 1.second)

    event
  end
end
