class MotionService
  def self.create(motion:, actor:)
    motion.author = actor
    actor.ability.authorize! :create, motion
    return false unless motion.valid?
    motion.save!

    reader = DiscussionReader.for(user: actor, discussion: motion.discussion)
    event = Events::NewMotion.publish!(motion)

    ThreadSearchService.index! motion.discussion_id
    reader.set_volume_as_required!
    reader.viewed!(motion.created_at + 1.second)
    event
  end

  def self.update(motion:, params:, actor:)

    if params[:closing_at] && motion.closing_at.to_s == Time.zone.parse(params[:closing_at]).to_s
      params.delete(:closing_at)
    end

    motion.attributes = params

    actor.ability.authorize! :update, motion

    if motion.valid?
      sync_search_vector = motion.name_changed? || motion.description_changed?

      if motion.name_changed?
        Events::MotionNameEdited.publish!(motion, actor)
      end

      if motion.description_changed?
        Events::MotionDescriptionEdited.publish!(motion, actor)
      end

      if motion.closing_at_changed?
        Events::MotionCloseDateEdited.publish!(motion, actor)
      end

      motion.save
      ThreadSearchService.index! motion.discussion_id if sync_search_vector
    else
      false
    end
  end

  def self.close_all_lapsed_motions
    Motion.lapsed_but_not_closed.each do |motion|
      close(motion)
    end
  end

  def self.reopen(motion, close_at)
    motion.closed_at = nil
    motion.closing_at = close_at
    motion.save!
    motion.did_not_votes.delete_all
  end

  def self.close(motion)
    motion.store_users_that_didnt_vote
    motion.closed_at = Time.now
    motion.save!

    Events::MotionClosed.publish!(motion)
  end

  def self.close_by_user(motion, user)
    user.ability.authorize! :close, motion

    motion.store_users_that_didnt_vote
    motion.closed_at = Time.now
    motion.save!

    Events::MotionClosedByUser.publish!(motion, user)
  end

  def self.create_outcome(motion:, params:, actor:)
    motion.outcome_author = actor
    motion.outcome = params[:outcome]

    return false unless motion.valid?
    actor.ability.authorize! :create_outcome, motion

    motion.save!
    Events::MotionOutcomeCreated.publish!(motion, actor)
  end

  def self.update_outcome(motion:, params:, actor:)
    motion.outcome_author = actor
    motion.outcome = params[:outcome]

    return false unless motion.valid?
    actor.ability.authorize! :update_outcome, motion

    motion.save!
    Events::MotionOutcomeUpdated.publish!(motion, actor)
  end
end
