import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "add-raffle-composer-button",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (!siteSettings.raffle_enabled) {
      return;
    }

    withPluginApi("0.8.7", (api) => {
      api.addComposerToolbarPopupMenuOption({
        icon: "trophy",
        label: "raffle.composer_button_title",
        action: (toolbar) => {
          api.container.lookup("service:modal").show("raffle-editor", {
            model: { topic: toolbar.topic },
          });
        },
        condition: (composer) => {
          return composer.creatingTopic || (composer.editingTopic && composer.post.post_number === 1);
        },
      });
    });
  },
};
