# name: discourse-advanced-raffle
# about: A plugin to create advanced raffles/lotteries in Discourse topics.
# version: 0.1
# authors: Your Name / Company
# url: https://github.com/your-repo/discourse-advanced-raffle

# 依赖 config/settings.yml 文件来定义这个设置
enabled_site_setting :raffle_enabled

after_initialize do
  
  # === 这是本次修改的核心 ===
  # 强制 Rails 立即加载我们插件的所有 Ruby 文件
  # 确保在后续代码执行时，所有类（如 LotteryActivity）都已定义
  plugin_root = File.expand_path("..", __FILE__)
  [
    "#{plugin_root}/app/models",
    "#{plugin_root}/app/serializers",
    "#{plugin_root}/app/controllers",
    "#{plugin_root}/app/services",
    "#{plugin_root}/lib/jobs"
  ].each do |path|
    # 将目录添加到 Rails 的预加载路径中
    Rails.configuration.eager_load_paths << path
  end
  # 触发一次预加载
  Zeitwerk::Loader.eager_load_all

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
        # ... Controller 代码保持不变 ...
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

  # 4. 定时任务部分
  # 由于我们已经预加载了所有文件，这里不需要再做任何事情
end
