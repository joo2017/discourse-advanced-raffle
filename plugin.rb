# name: discourse-advanced-raffle
# about: A plugin to create advanced raffles/lotteries in Discourse topics.
# version: 0.1
# authors: Your Name / Company
# url: https://github.com/your-repo/discourse-advanced-raffle

# 依赖 config/settings.yml 文件来定义这个设置
enabled_site_setting :raffle_enabled

# 将所有扩展代码都放在 after_initialize 块中
after_initialize do
  # Discourse 的 Zeitwerk 加载器会自动处理 app/, lib/ 等目录
  # 我们不需要手动进行任何加载操作

  # 1. 扩展核心模型
  # 使用 PREPARE_PLUGIN_STORE 来确保在开发环境中的代码重载
  Discourse::Application.reloader.to_prepare do
    Topic.class_eval do
      has_one :lottery_activity, class_name: "LotteryActivity", dependent: :destroy
    end

    # 2. 扩展核心序列化器
    require_dependency "topic_view_serializer"
    
    TopicViewSerializer.class_eval do
      # 定义一个私有辅助方法，这是最佳实践
      private def lottery_activity_for
        object.topic&.lottery_activity
      end

      # 添加属性
      attribute :lottery_activity do
        activity = lottery_activity_for
        activity ? LotteryActivitySerializer.new(activity, root: false).as_json : nil
      end

      # 定义包含此属性的条件
      def include_lottery_activity?
        SiteSetting.raffle_enabled? && lottery_activity_for.present?
      end
    end
  end

  # 3. 定义插件自己的控制器和路由
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
end
