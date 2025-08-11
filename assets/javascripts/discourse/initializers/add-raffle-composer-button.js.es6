import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "add-raffle-composer-button",

  initialize(container) {
    // 确保我们只在 Discourse 的主应用中运行
    const siteSettings = container.lookup("site-settings:main");
    if (!siteSettings) { return; }

    withPluginApi("1.0.0", (api) => {
      // 检查插件是否在后台启用
      if (!siteSettings.raffle_enabled) {
        return;
      }

      // 使用 addComposerToolbarButton 直接在工具栏添加一个按钮
      api.addComposerToolbarButton({
        id: "setup-raffle-button", // 按钮的唯一 ID
        group: "insertions",       // 按钮所属的分组
        icon: "trophy",            // 按钮图标
        label: "raffle.composer_button_title", // 鼠标悬停时的标题
        
        // 点击按钮时执行的动作
        action: (toolbar) => {
          api.container.lookup("service:modal").show("raffle-editor", {
            model: { topic: toolbar.topic },
          });
        },
        
        // 决定按钮是否显示的条件
        condition: (composer) => {
          return composer.creatingTopic || (composer.editingTopic && composer.post.post_number === 1);
        },
      });
    });
  },
};
