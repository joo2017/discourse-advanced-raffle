import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "add-raffle-composer-button",

  initialize(container) {
    // 确保插件在后台设置中是启用的
    const siteSettings = container.lookup("site-settings:main");
    if (!siteSettings.raffle_enabled) {
      return;
    }

    withPluginApi("0.8.7", (api) => {
      // 在编辑器的齿轮菜单中添加一个按钮
      api.addComposerToolbarPopupMenuOption({
        icon: "trophy",
        label: "raffle.composer_button_title",
        
        // 这是最关键的 action 部分，负责打开模态框
        action: (toolbar) => {
          // "raffle-editor" 是根据我们的组件文件名自动生成的名字
          // 我们将 composer 的 model (也就是 topic) 传递给模态框
          api.container.lookup("service:modal").show("raffle-editor", {
            model: { topic: toolbar.topic },
          });
        },
        
        // 这个按钮只在编辑主楼时显示
        condition: (composer) => {
          return composer.creatingTopic || (composer.editingTopic && composer.post.post_number === 1);
        },
      });
    });
  },
};
