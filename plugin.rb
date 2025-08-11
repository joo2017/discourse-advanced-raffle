# name: discourse-advanced-raffle
# about: A plugin to create advanced raffles/lotteries in Discourse topics.
# version: 0.1
# authors: Your Name / Company
# url: https://github.com/your-repo/discourse-advanced-raffle

after_initialize do
  # 将所有插件相关的代码都放在这里，确保 Discourse 核心已加载
  
  # 1. 注册站点设置
  enabled_site_setting :raffle_enabled
  
  # 2. 扩展核心模型
  Topic.class_eval do
    has_one :lottery_activity, class_name: "LotteryActivity", dependent: :destroy
  end

  # 3. 定义控制器和路由
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

  # 4. 扩展序列化器 (使用最新的 API 规范)
  require_dependency "topic_view_serializer"

  # 这是本次修改的核心
  add_to_serializer(:topic_view, :lottery_activity, respect_plugin_enabled: false) do
    # 使用关键字参数 `respect_plugin_enabled: false` 替代旧的第三个参数
    # 如果 lottery_activity 存在，则序列化它
    object.topic&.lottery_activity ? LotteryActivitySerializer.new(object.topic.lottery_activity, root: false).as_json : nil
  end

  # 使用 include_condition 替代 include_*? 方法
  # 这是本次修改的另一个核心
  TopicViewSerializer.add_include_condition(:lottery_activity) do
    # 只有当插件启用且活动存在时，才包含此字段
    SiteSetting.raffle_enabled? && object.topic&.lottery_activity.present?
  end
end
