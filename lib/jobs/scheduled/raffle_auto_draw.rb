# Located in: plugins/discourse-advanced-raffle/lib/jobs/scheduled/raffle_auto_draw.rb

module Jobs
  class RaffleAutoDraw < ::Jobs::Scheduled
    every 1.minute

    def execute(args)
      # 1. 确保插件在站点设置中已启用
      return unless SiteSetting.raffle_enabled?

      find_and_draw_raffles
    end

    private

    def find_and_draw_raffles
      # 使用 includes(:topic) 预加载关联的 topic, 提高效率
      LotteryActivity.includes(:topic).where(status: :active).find_each do |activity|
        # 2. 捕获所有可能的异常，防止单个活动的失败导致整个定时任务中断
        begin
          # 3. 边缘情况防护: 如果活动关联的 topic 已被删除，则跳过
          if activity.topic.nil?
            Rails.logger.warn "RaffleAutoDraw Job: Skipping activity ##{activity.id} because its topic has been deleted."
            # 可选：将此活动标记为已取消，以防止未来的无效检查
            # activity.update(status: :cancelled)
            next
          end

          # 4. 判断是否达到开奖条件
          if should_draw?(activity)
            Rails.logger.info "RaffleAutoDraw Job: Triggering draw for activity ##{activity.id} on topic '#{activity.topic.title}'."
            result = Lottery::DrawService.call(activity)

            # 5. 增强日志: 如果服务返回失败，记录下失败原因
            unless result[:success]
              Rails.logger.warn "RaffleAutoDraw Job: Draw Service failed for activity ##{activity.id}. Reason: #{result[:error]}"
            end
          end
        rescue => e
          # 6. 异常处理: 记录下详细的错误信息，方便排查问题
          Rails.logger.error "RaffleAutoDraw Job: EXCEPTION processing activity ##{activity.id}. Message: #{e.message}, Backtrace: #{e.backtrace.join("\n")}"
        end
      end
    end

    def should_draw?(activity)
      # 按时间开奖
      if activity.by_time?
        return activity.end_time.present? && Time.current >= activity.end_time
      end

      # 按楼层数开奖
      if activity.by_floor?
        condition_floor = activity.draw_condition['floor'].to_i
        # 实时统计有效回帖数 (post_number > 1)
        current_floor = activity.topic.posts.where("post_number > 1").count
        
        return condition_floor > 0 && current_floor >= condition_floor
      end

      # 手动开奖的活动不会被此任务处理
      false
    end
  end
end
