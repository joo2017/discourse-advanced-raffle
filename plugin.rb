# name: discourse-advanced-raffle
# about: A plugin to create advanced raffles/lotteries in Discourse topics.
# version: 0.1
# authors: Your Name / Company
# url: https://github.com/your-repo/discourse-advanced-raffle

# 依赖 config/settings.yml 文件来定义这个设置
enabled_site_setting :raffle_enabled

after_initialize do
  
  # 1. 扩展核心模型
  Topic.class_eval do
    has_one :lottery_activity, class_name: "LotteryActivity", dependent: :destroy
  end

  # 2. 定义控制器和路由
  module ::DiscourseAdvancedRaffle
    # ... Controller 和 Engine 的代码保持不变 ...
    class RafflesController < ::ApplicationController
      requires_plugin 'discourse-advanced-raffle'
      before_action :ensure_logged_in

      def update
        raise Discourse::InvalidAccess.new unless SiteSetting.raffle_enabled?

        topic = Topic.find_by(id: params[:topic_id])
        return render_json_error(I18n.t('topic.not_found'), status: 404) unless topic
        guardian.ensure_can_edit!(topic)

        activity = LotteryActivity.find_or_initialize_by(topic_id: topic.id)
        activity.user_id = current_user.id

        activity_params = params.require(:activity).permit(
          :status,
          :draw_type,
          :start_time,
          :end_time,
          draw_condition: {},
          participation_rules: {}
        )
        
        prizes_params = params.require(:activity).permit(prizes: [:id, :name, :description, :quantity, :image_url])[:prizes] || []

        ActiveRecord::Base.transaction do
          activity.assign_attributes(activity_params)
          activity.save!

          activity.prizes.destroy_all
          activity.prizes.create!(prizes_params) if prizes_params.present?
        end

        render json: LotteryActivitySerializer.new(activity, root: false).as_json
      rescue ActiveRecord::RecordInvalid => e
        render_json_error(e.message, status: 422)
      end
    end

    class Engine < ::Rails::Engine
      engine_name 'discourse_advanced_raffle'
      isolate_namespace DiscourseAdvancedRaffle
    end

    Engine.routes.draw do
      put '/:topic_id' => 'raffles#update'
    end
  end

  Discourse::Application.routes.append do
    mount DiscourseAdvancedRaffle::Engine, at: '/raffles'
  end

  # 3. 扩展序列化器 (修正作用域问题)
  require_dependency "topic_view_serializer"
  
  # === 这是本次修改的核心 ===
  # 我们需要在 TopicViewSerializer 类的上下文中定义这个方法
  TopicViewSerializer.class_eval do
    # 将辅助方法定义在 class_eval 块内部
    # 这样它就成为了 TopicViewSerializer 的一个实例方法
    def lottery_activity_for
      # 在实例方法中，`object` 就是 topic_view 对象
      object.topic&.lottery_activity
    end
  end

  # 现在，下面的代码块在执行时，就可以找到这个方法了
  add_to_serializer(:topic_view, :lottery_activity, false) do
    activity = lottery_activity_for # 注意：这里直接调用，不需要传递参数
    activity ? LotteryActivitySerializer.new(activity, root: false).as_json : nil
  end

  add_to_serializer(:topic_view, :include_lottery_activity?) do
    SiteSetting.raffle_enabled? && lottery_activity_for.present?
  end

  # 4. 定时任务部分保持不变
  require_dependency 'jobs/scheduled/raffle_auto_draw'
  Jobs::RaffleAutoDraw.class_eval do
    def execute(args)
      return unless SiteSetting.raffle_enabled?
      find_and_draw_raffles
    end
  end
end
