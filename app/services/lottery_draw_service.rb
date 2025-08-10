module Lottery
  class DrawService
    def initialize(activity)
      @activity = activity
      @topic = activity.topic
      @rules = activity.participation_rules.with_indifferent_access
    end

    def self.call(activity)
      new(activity).call
    end

    def call
      Rails.logger.info "Raffle Draw Service: Starting for activity ##{@activity.id}."

      return { success: false, error: "Raffle is not active." } unless @activity.active?

      participants = find_valid_participants
      if participants.empty?
        @activity.update!(status: :finished)
        Rails.logger.info "Raffle Draw Service: No valid participants for activity ##{@activity.id}. Closing raffle."
        return { success: true, winners_count: 0, message: "No participants." }
      end

      prizes = @activity.prizes.flat_map { |p| [p] * p.quantity }
      if prizes.empty?
        @activity.update!(status: :finished)
        Rails.logger.warn "Raffle Draw Service: No prizes configured for activity ##{@activity.id}. Closing raffle."
        return { success: false, error: "No prizes available." }
      end

      winners_to_create = []
      begin
        ActiveRecord::Base.transaction do
          shuffled_participants = participants.shuffle
          num_winners = [shuffled_participants.length, prizes.length].min
          
          shuffled_participants.first(num_winners).each_with_index do |participant, index|
            winners_to_create << {
              lottery_activity_id: @activity.id,
              lottery_prize_id: prizes[index].id,
              user_id: participant[:user_id],
              post_id: participant[:post_id],
              draw_time: Time.current,
              created_at: Time.current,
              updated_at: Time.current
            }
          end

          if winners_to_create.any?
            LotteryWinner.insert_all!(winners_to_create)
          end
          @activity.update!(status: :finished)
        end
      rescue => e
        Rails.logger.error "Raffle Draw Service: FAILED for activity ##{@activity.id}. Error: #{e.message}"
        return { success: false, error: "An unexpected error occurred during the draw." }
      end

      Rails.logger.info "Raffle Draw Service: SUCCESS for activity ##{@activity.id}. Drew #{winners_to_create.length} winners."

      { success: true, winners_count: winners_to_create.length }
    end

    private

    def find_valid_participants
      base_posts = Post.includes(user: :groups)
                       .where(topic_id: @topic.id)
                       .where("post_number > 1")
                       .where(deleted_at: nil)

      if @activity.start_time && @activity.end_time
        base_posts = base_posts.where(created_at: @activity.start_time..@activity.end_time)
      end

      allowed_group_ids = @rules[:allowed_groups].is_a?(Array) ? @rules[:allowed_groups].compact.map(&:to_i) : []

      valid_participants = []
      base_posts.find_each do |post|
        user = post.user
        next if user.nil? || user.staged?

        if @rules[:keyword].present? && !post.raw.downcase.include?(@rules[:keyword].downcase)
          next
        end

        if @rules[:min_level].present? && user.trust_level < @rules[:min_level].to_i
          next
        end
        
        if allowed_group_ids.present? && (user.groups.pluck(:id) & allowed_group_ids).empty?
          next
        end

        valid_participants << { user_id: user.id, post_id: post.id }
      end

      if @rules[:unique_user]
        return valid_participants.uniq { |p| p[:user_id] }
      end

      valid_participants
    end
  end
end
