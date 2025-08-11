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
    class RafflesController < ::ApplicationController
      requires_plugin 'discourse-advanced-raffle'
      before_action :ensure_logged_in

      def update
        # 增加对 SiteSetting 的检查
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

  # 3. 扩展序列化器 (使用最稳定、兼容性最强的 API 写法)
  require_dependency "topic_view_serializer"
  
  def lottery_activity_for(topic_view)
    topic_view.topic&.lottery_activity
  end

  add_to_serializer(:topic_view, :lottery_activity, false) do
    activity = lottery_activity_for(object)
    activity ? LotteryActivitySerializer.new(activity, root: false).as_json : nil
  end

  add_to_serializer(:topic_view, :include_lottery_activity?) do
    # 恢复对 SiteSetting 的检查
    SiteSetting.raffle_enabled? && lottery_activity_for(object).present?
  end

  # 4. 修改定时任务，恢复 SiteSetting 检查
  # 我们需要确保定时任务的文件也被正确加载
  require_dependency File.expand_path('../lib/jobs/scheduled/raffle_auto_draw.rb', __FILE__)
  
  # Discourse 核心会自动加载 lib/jobs/scheduled 下的文件，
  # 但为了确保 class_eval 时类已加载，显式 require 更安全
  Jobs::RaffleAutoDraw.class_eval do
    def execute(args)
      # 恢复检查
      return unless SiteSetting.raffle_enabled?
      find_and_draw_raffles
    end
  end
end
