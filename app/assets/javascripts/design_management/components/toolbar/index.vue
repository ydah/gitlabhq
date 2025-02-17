<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlButton, GlIcon, GlTooltipDirective, GlSkeletonLoader } from '@gitlab/ui';
import permissionsQuery from 'shared_queries/design_management/design_permissions.query.graphql';
import { __, s__, sprintf } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { DESIGNS_ROUTE_NAME } from '../../router/constants';
import DeleteButton from '../delete_button.vue';
import DesignTodoButton from '../design_todo_button.vue';
import DesignNavigation from './design_navigation.vue';

export default {
  i18n: {
    downloadButtonLabel: s__('DesignManagement|Download design'),
  },
  components: {
    GlButton,
    GlIcon,
    GlSkeletonLoader,
    DesignNavigation,
    DeleteButton,
    DesignTodoButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [timeagoMixin],
  inject: {
    projectPath: {
      default: '',
    },
    issueIid: {
      default: '',
    },
  },
  props: {
    id: {
      type: String,
      required: true,
    },
    isDeleting: {
      type: Boolean,
      required: true,
    },
    filename: {
      type: String,
      required: false,
      default: '',
    },
    updatedAt: {
      type: String,
      required: false,
      default: null,
    },
    updatedBy: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isLatestVersion: {
      type: Boolean,
      required: true,
    },
    image: {
      type: String,
      required: false,
      default: '',
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    design: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      permissions: {
        createDesign: false,
      },
    };
  },
  apollo: {
    permissions: {
      query: permissionsQuery,
      variables() {
        return {
          fullPath: this.projectPath,
          iid: this.issueIid,
        };
      },
      update: (data) => data.project.issue.userPermissions,
    },
  },
  computed: {
    updatedText() {
      return sprintf(__('Updated %{updated_at} by %{updated_by}'), {
        updated_at: this.timeFormatted(this.updatedAt),
        updated_by: this.updatedBy.name,
      });
    },
    canDeleteDesign() {
      return this.permissions.createDesign;
    },
  },
  DESIGNS_ROUTE_NAME,
};
</script>

<template>
  <header
    class="gl-display-flex gl-align-items-center gl-justify-content-space-between gl-bg-white gl-py-4 gl-pl-5 gl-border-b js-design-header"
  >
    <div class="gl-display-flex gl-align-items-center">
      <div class="gl-overflow-hidden gl-display-flex gl-align-items-center">
        <gl-skeleton-loader v-if="isLoading" :lines="1" />
        <h2 v-else class="gl-m-0 str-truncated-100 gl-font-base">{{ filename }}</h2>
        <small v-if="updatedAt" class="gl-text-gray-500">{{ updatedText }}</small>
      </div>
    </div>
    <design-navigation :id="id" class="gl-ml-auto gl-flex-shrink-0" />
    <design-todo-button :design="design" class="gl-mr-3" @error="$emit('todoError', $event)" />
    <gl-button
      v-gl-tooltip.bottom
      :href="image"
      icon="download"
      :title="$options.i18n.downloadButtonLabel"
      :aria-label="$options.i18n.downloadButtonLabel"
    />
    <delete-button
      v-if="isLatestVersion && canDeleteDesign"
      v-gl-tooltip.bottom
      class="gl-ml-3"
      :is-deleting="isDeleting"
      button-variant="default"
      button-icon="archive"
      button-category="secondary"
      :title="s__('DesignManagement|Archive design')"
      @delete-selected-designs="$emit('delete')"
    />
    <div class="gl-ml-5 gl-border-l">
      <router-link
        :to="{
          name: $options.DESIGNS_ROUTE_NAME,
          query: $route.query,
        }"
        :aria-label="s__('DesignManagement|Go back to designs')"
        data-testid="close-design"
        class="btn btn-default-tertiary gl-display-flex gl-align-items-center gl-justify-content-center text-plain gl-p-3 gl-mx-3 gl-border-0"
        tag="button"
      >
        <gl-icon name="close" />
      </router-link>
    </div>
  </header>
</template>
