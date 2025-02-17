import { GlLoadingIcon, GlKeysetPagination, GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended, extendedWrapper } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getBinding } from 'helpers/vue_mock_directive';
import PackagesProtectionRules from '~/packages_and_registries/settings/project/components/packages_protection_rules.vue';
import PackagesProtectionRuleForm from '~/packages_and_registries/settings/project/components/packages_protection_rule_form.vue';
import SettingsBlock from '~/packages_and_registries/shared/components/settings_block.vue';
import packagesProtectionRuleQuery from '~/packages_and_registries/settings/project/graphql/queries/get_packages_protection_rules.query.graphql';
import deletePackagesProtectionRuleMutation from '~/packages_and_registries/settings/project/graphql/mutations/delete_packages_protection_rule.mutation.graphql';
import {
  packagesProtectionRuleQueryPayload,
  packagesProtectionRulesData,
  deletePackagesProtectionRuleMutationPayload,
} from '../mock_data';

Vue.use(VueApollo);

describe('Packages protection rules project settings', () => {
  let wrapper;
  let fakeApollo;

  const defaultProvidedValues = {
    projectPath: 'path',
  };

  const $toast = { show: jest.fn() };

  const findSettingsBlock = () => wrapper.findComponent(SettingsBlock);
  const findTable = () => extendedWrapper(wrapper.findByRole('table', /protected packages/i));
  const findTableBody = () => extendedWrapper(findTable().findAllByRole('rowgroup').at(1));
  const findTableRow = (i) => extendedWrapper(findTableBody().findAllByRole('row').at(i));
  const findTableRowButtonDelete = (i) => findTableRow(i).findByRole('button', { name: /delete/i });
  const findTableLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findProtectionRuleForm = () => wrapper.findComponent(PackagesProtectionRuleForm);
  const findAddProtectionRuleButton = () =>
    wrapper.findByRole('button', { name: /add package protection rule/i });
  const findAlert = () => wrapper.findByRole('alert');
  const findModal = () => wrapper.findComponent(GlModal);

  const mountComponent = (mountFn = shallowMount, provide = defaultProvidedValues, config) => {
    wrapper = mountFn(PackagesProtectionRules, {
      stubs: {
        SettingsBlock,
        GlModal: true,
      },
      mocks: {
        $toast,
      },
      provide,
      ...config,
    });
  };

  const createComponent = ({
    mountFn = shallowMount,
    provide = defaultProvidedValues,
    packagesProtectionRuleQueryResolver = jest
      .fn()
      .mockResolvedValue(packagesProtectionRuleQueryPayload()),
    deletePackagesProtectionRuleMutationResolver = jest
      .fn()
      .mockResolvedValue(deletePackagesProtectionRuleMutationPayload()),
    config = {},
  } = {}) => {
    const requestHandlers = [
      [packagesProtectionRuleQuery, packagesProtectionRuleQueryResolver],
      [deletePackagesProtectionRuleMutation, deletePackagesProtectionRuleMutationResolver],
    ];

    fakeApollo = createMockApollo(requestHandlers);

    mountComponent(mountFn, provide, {
      apolloProvider: fakeApollo,
      ...config,
    });
  };

  it('renders the setting block with table', async () => {
    createComponent({ mountFn: mountExtended });

    await waitForPromises();

    expect(findSettingsBlock().exists()).toBe(true);
    expect(findTable().exists()).toBe(true);
  });

  describe('table "package protection rules"', () => {
    it('renders table with packages protection rules', async () => {
      createComponent({ mountFn: mountExtended });

      await waitForPromises();

      expect(findTable().exists()).toBe(true);

      packagesProtectionRuleQueryPayload().data.project.packagesProtectionRules.nodes.forEach(
        (protectionRule, i) => {
          expect(findTableRow(i).text()).toContain(protectionRule.packageNamePattern);
          expect(findTableRow(i).text()).toContain('npm');
          expect(findTableRow(i).text()).toContain('Maintainer');
        },
      );
    });

    it('displays table in busy state and shows loading icon inside table', async () => {
      createComponent({ mountFn: mountExtended });

      expect(findTableLoadingIcon().exists()).toBe(true);
      expect(findTableLoadingIcon().attributes('aria-label')).toBe('Loading');

      expect(findTable().attributes('aria-busy')).toBe('true');

      await waitForPromises();

      expect(findTableLoadingIcon().exists()).toBe(false);
      expect(findTable().attributes('aria-busy')).toBe('false');
    });

    it('calls graphql api query', () => {
      const packagesProtectionRuleQueryResolver = jest
        .fn()
        .mockResolvedValue(packagesProtectionRuleQueryPayload());
      createComponent({ packagesProtectionRuleQueryResolver });

      expect(packagesProtectionRuleQueryResolver).toHaveBeenCalledWith(
        expect.objectContaining({ projectPath: defaultProvidedValues.projectPath }),
      );
    });

    describe('table pagination', () => {
      const findPagination = () => wrapper.findComponent(GlKeysetPagination);

      it('renders pagination', async () => {
        createComponent({ mountFn: mountExtended });

        await waitForPromises();

        expect(findPagination().exists()).toBe(true);
        expect(findPagination().props()).toMatchObject({
          endCursor: '10',
          startCursor: '0',
          hasNextPage: true,
          hasPreviousPage: false,
        });
      });

      it('calls initial graphql api query with pagination information', () => {
        const packagesProtectionRuleQueryResolver = jest
          .fn()
          .mockResolvedValue(packagesProtectionRuleQueryPayload());
        createComponent({ packagesProtectionRuleQueryResolver });

        expect(packagesProtectionRuleQueryResolver).toHaveBeenCalledWith(
          expect.objectContaining({
            projectPath: defaultProvidedValues.projectPath,
            first: 10,
          }),
        );
      });

      describe('when button "Previous" is clicked', () => {
        const packagesProtectionRuleQueryResolver = jest
          .fn()
          .mockResolvedValueOnce(
            packagesProtectionRuleQueryPayload({
              nodes: packagesProtectionRulesData.slice(10),
              pageInfo: {
                hasNextPage: false,
                hasPreviousPage: true,
                startCursor: '10',
                endCursor: '16',
              },
            }),
          )
          .mockResolvedValueOnce(packagesProtectionRuleQueryPayload());

        const findPaginationButtonPrev = () =>
          extendedWrapper(findPagination()).findByRole('button', { name: 'Previous' });

        beforeEach(async () => {
          createComponent({ mountFn: mountExtended, packagesProtectionRuleQueryResolver });

          await waitForPromises();

          findPaginationButtonPrev().trigger('click');
        });

        it('sends a second graphql api query with new pagination params', () => {
          expect(packagesProtectionRuleQueryResolver).toHaveBeenCalledTimes(2);
          expect(packagesProtectionRuleQueryResolver).toHaveBeenLastCalledWith(
            expect.objectContaining({
              before: '10',
              last: 10,
              projectPath: 'path',
            }),
          );
        });
      });

      describe('when button "Next" is clicked', () => {
        const packagesProtectionRuleQueryResolver = jest
          .fn()
          .mockResolvedValueOnce(packagesProtectionRuleQueryPayload())
          .mockResolvedValueOnce(
            packagesProtectionRuleQueryPayload({
              nodes: packagesProtectionRulesData.slice(10),
              pageInfo: {
                hasNextPage: true,
                hasPreviousPage: false,
                startCursor: '1',
                endCursor: '10',
              },
            }),
          );

        const findPaginationButtonNext = () =>
          extendedWrapper(findPagination()).findByRole('button', { name: 'Next' });

        beforeEach(async () => {
          createComponent({ mountFn: mountExtended, packagesProtectionRuleQueryResolver });

          await waitForPromises();

          findPaginationButtonNext().trigger('click');
        });

        it('sends a second graphql api query with new pagination params', () => {
          expect(packagesProtectionRuleQueryResolver).toHaveBeenCalledTimes(2);
          expect(packagesProtectionRuleQueryResolver).toHaveBeenLastCalledWith(
            expect.objectContaining({
              after: '10',
              first: 10,
              projectPath: 'path',
            }),
          );
        });
      });
    });

    describe('table rows', () => {
      describe('button "Delete"', () => {
        it('exists in table', async () => {
          createComponent({ mountFn: mountExtended });

          await waitForPromises();

          expect(findTableRowButtonDelete(0).exists()).toBe(true);
        });

        describe('when button is clicked', () => {
          it('binds confirmation modal', async () => {
            createComponent({ mountFn: mountExtended });

            await waitForPromises();

            const modalId = getBinding(findTableRowButtonDelete(0).element, 'gl-modal');

            expect(findModal().props('modal-id')).toBe(modalId);
            expect(findModal().props('title')).toBe(
              'Are you sure you want to delete the package protection rule?',
            );
            expect(findModal().text()).toBe(
              'Users with at least the Developer role for this project will be able to publish, edit, and delete packages.',
            );
          });
        });
      });
    });
  });

  describe('modal "confirmation"', () => {
    const createComponentAndClickButtonDeleteInTableRow = async ({
      tableRowIndex = 0,
      deletePackagesProtectionRuleMutationResolver = jest
        .fn()
        .mockResolvedValue(deletePackagesProtectionRuleMutationPayload()),
    } = {}) => {
      createComponent({
        mountFn: mountExtended,
        deletePackagesProtectionRuleMutationResolver,
      });

      await waitForPromises();

      findTableRowButtonDelete(tableRowIndex).trigger('click');
    };

    describe('when modal button "primary" clicked', () => {
      const clickOnModalPrimaryBtn = () => findModal().vm.$emit('primary');

      it('disables the button when graphql mutation is executed', async () => {
        await createComponentAndClickButtonDeleteInTableRow();

        await clickOnModalPrimaryBtn();

        expect(findTableRowButtonDelete(0).props().disabled).toBe(true);

        expect(findTableRowButtonDelete(1).props().disabled).toBe(false);
      });

      it('sends graphql mutation', async () => {
        const deletePackagesProtectionRuleMutationResolver = jest
          .fn()
          .mockResolvedValue(deletePackagesProtectionRuleMutationPayload());

        await createComponentAndClickButtonDeleteInTableRow({
          deletePackagesProtectionRuleMutationResolver,
        });

        await clickOnModalPrimaryBtn();

        expect(deletePackagesProtectionRuleMutationResolver).toHaveBeenCalledTimes(1);
        expect(deletePackagesProtectionRuleMutationResolver).toHaveBeenCalledWith({
          input: { id: packagesProtectionRulesData[0].id },
        });
      });

      it('handles erroneous graphql mutation', async () => {
        const alertErrorMessage = 'Client error message';
        const deletePackagesProtectionRuleMutationResolver = jest
          .fn()
          .mockRejectedValue(new Error(alertErrorMessage));

        await createComponentAndClickButtonDeleteInTableRow({
          deletePackagesProtectionRuleMutationResolver,
        });

        await clickOnModalPrimaryBtn();

        await waitForPromises();

        expect(findAlert().isVisible()).toBe(true);
        expect(findAlert().text()).toBe(alertErrorMessage);
      });

      it('handles graphql mutation with error response', async () => {
        const alertErrorMessage = 'Server error message';
        const deletePackagesProtectionRuleMutationResolver = jest.fn().mockResolvedValue({
          data: {
            deletePackagesProtectionRule: {
              packageProtectionRule: null,
              errors: [alertErrorMessage],
            },
          },
        });

        await createComponentAndClickButtonDeleteInTableRow({
          deletePackagesProtectionRuleMutationResolver,
        });

        await clickOnModalPrimaryBtn();

        await waitForPromises();

        expect(findAlert().isVisible()).toBe(true);
        expect(findAlert().text()).toBe(alertErrorMessage);
      });

      it('refetches package protection rules after successful graphql mutation', async () => {
        const deletePackagesProtectionRuleMutationResolver = jest
          .fn()
          .mockResolvedValue(deletePackagesProtectionRuleMutationPayload());

        const packagesProtectionRuleQueryResolver = jest
          .fn()
          .mockResolvedValue(packagesProtectionRuleQueryPayload());

        createComponent({
          mountFn: mountExtended,
          packagesProtectionRuleQueryResolver,
          deletePackagesProtectionRuleMutationResolver,
        });

        await waitForPromises();

        expect(packagesProtectionRuleQueryResolver).toHaveBeenCalledTimes(1);

        await findTableRowButtonDelete(0).trigger('click');

        await clickOnModalPrimaryBtn();

        await waitForPromises();

        expect(packagesProtectionRuleQueryResolver).toHaveBeenCalledTimes(2);
      });

      it('shows a toast with success message', async () => {
        await createComponentAndClickButtonDeleteInTableRow();

        await clickOnModalPrimaryBtn();

        await waitForPromises();

        expect($toast.show).toHaveBeenCalledWith('Package protection rule deleted.');
      });
    });
  });

  it('does not initially render package protection form', async () => {
    createComponent({ mountFn: mountExtended });

    await waitForPromises();

    expect(findAddProtectionRuleButton().isVisible()).toBe(true);
    expect(findProtectionRuleForm().exists()).toBe(false);
  });

  describe('button "Add protection rule"', () => {
    it('button exists', async () => {
      createComponent({ mountFn: mountExtended });

      await waitForPromises();

      expect(findAddProtectionRuleButton().isVisible()).toBe(true);
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        createComponent({ mountFn: mountExtended });

        await waitForPromises();

        await findAddProtectionRuleButton().trigger('click');
      });

      it('renders package protection form', () => {
        expect(findProtectionRuleForm().isVisible()).toBe(true);
      });

      it('disables the button "add protection rule"', () => {
        expect(findAddProtectionRuleButton().attributes('disabled')).toBeDefined();
      });
    });
  });

  describe('form "add protection rule"', () => {
    let packagesProtectionRuleQueryResolver;

    beforeEach(async () => {
      packagesProtectionRuleQueryResolver = jest
        .fn()
        .mockResolvedValue(packagesProtectionRuleQueryPayload());

      createComponent({ packagesProtectionRuleQueryResolver, mountFn: mountExtended });

      await waitForPromises();

      await findAddProtectionRuleButton().trigger('click');
    });

    it('handles event "submit"', async () => {
      await findProtectionRuleForm().vm.$emit('submit');

      expect(packagesProtectionRuleQueryResolver).toHaveBeenCalledTimes(2);

      expect(findProtectionRuleForm().exists()).toBe(false);
      expect(findAddProtectionRuleButton().attributes('disabled')).not.toBeDefined();
    });

    it('handles event "cancel"', async () => {
      await findProtectionRuleForm().vm.$emit('cancel');

      expect(packagesProtectionRuleQueryResolver).toHaveBeenCalledTimes(1);

      expect(findProtectionRuleForm().exists()).toBe(false);
      expect(findAddProtectionRuleButton().attributes()).not.toHaveProperty('disabled');
    });
  });

  describe('alert "errorMessage"', () => {
    const findAlertButtonDismiss = () => wrapper.findByRole('button', { name: /dismiss/i });

    it('renders alert and dismisses it correctly', async () => {
      const alertErrorMessage = 'Error message';
      createComponent({
        mountFn: mountExtended,
        config: {
          data() {
            return {
              alertErrorMessage,
            };
          },
        },
      });

      await waitForPromises();

      expect(findAlert().isVisible()).toBe(true);
      expect(findAlert().text()).toBe(alertErrorMessage);

      await findAlertButtonDismiss().trigger('click');

      expect(findAlert().exists()).toBe(false);
    });
  });
});
