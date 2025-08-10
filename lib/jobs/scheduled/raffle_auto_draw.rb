module Jobs
  class RaffleAutoDraw < ::Jobs::Scheduled
    every 1.minute

    def execute(args)
      return unless SiteSetting.raffle_enabled?

      find_and_draw_raffles
    end

    private

    def find_and_draw_raffles
      LotteryActivity.includes(:topic).where(status: :active).find_each do |activity|
        begin
          if activity.topic.nil?
            Rails.logger.warn "RaffleAutoDraw Job: Skipping activity ##{activity.id} because its topic has been deleted."
            next
          end

          if should_draw?(activity)
            Rails.logger.info "RaffleAutoDraw Job: Triggering draw for activity ##{activity.id} on topic '#{activity.topic.title}'."
            result = Lottery::DrawService.call(activity)

            unless result[:success]
              Rails.logger.warn "RaffleAutoDraw Job: Draw Service failed for activity ##{activity.id}. Reason: #{result[:error]}"
            end
          end
        rescue => e
          Rails.logger.error "RaffleAutoDraw Job: EXCEPTION processing activity ##{activity.id}. Message: #{e.message}, Backtrace: #{e.backtrace.join("\n")}"
        end
      end
    end

    def should_draw?(activity)
      if activity.by_time?
        return activity.end_time.present? && Time.current >= activity.end_time
      end

      if activity.by_floor?
        condition_floor = activity.draw_condition['floor'].to_i
        current_floor = activity.topic.posts.where("post_number > 1").count
        
        return condition_floor > 0 && current_floor >= condition_floor
      end

      false
    end
  end
end
