# name: discourse-advanced-raffle
# about: A plugin to create advanced raffles/lotteries in Discourse topics.
# version: 0.1
# authors: Your Name / Company
# url: https://github.com/your-repo/discourse-advanced-raffle

# 依赖 config/settings.yml 文件来定义这个设置
enabled_site_setting :raffle_enabled

after_initialize do
  
  # Discourse 会自动加载 app/, lib/, config/ 下的文件。
  # 我们不需要手动 `require` 它们。

  # 1. 扩展核心模型
  Topic.class_eval do
    has_one :lottery_activity, class_name: "LotteryActivity", dependent: :destroy
  end

  # 2. 定义控制器和路由
  module ::DiscourseAdvancedRaffle
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
          :status, :draw_type, :start_time, :end_time,
          draw_condition: {}, participation_rules: {}
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

  # 3. 扩展序列化器
  # `require_dependency "topic_view_serializer"` 是必要的，因为它修改的是 Discourse 核心类
  require_dependency "topic_view_serializer"
  
  TopicViewSerializer.class_eval do
    def lottery_activity_for
      object.topic&.lottery_activity
    end
  end

  add_to_serializer(:topic_view, :lottery_activity, false) do
    activity = lottery_activity_for
    activity ? LotteryActivitySerializer.new(activity, root: false).as_json : nil
  end

  add_to_serializer(:topic_view, :include_lottery_activity?) do
    SiteSetting.raffle_enabled? && lottery_activity_for.present?
  end

  # 4. 定时任务的修改将在这里进行
  # 我们不再需要 `require_dependency` 来加载我们自己的文件
  # Discourse 的自动加载器会处理它。
  # 只有在 after_initialize 阶段，我们才能安全地对已加载的类进行 class_eval
  
  # 这里不需要任何代码来修改定时任务，因为它原始的定义已经是正确的了。
  # 我们之前添加的 class_eval 是为了移除 SiteSetting 检查，现在我们希望保留这个检查，
  # 所以我们不需要修改原始的 Jobs::RaffleAutoDraw 类。
end
