<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

import {
  buildTemplateParameters,
  getTemplateKey,
  isValidTemplateMediaUrl,
  findComponentByType,
  COMPONENT_TYPES,
  MEDIA_FORMATS,
} from 'dashboard/helper/templateHelper';

import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  templates: {
    type: Array,
    default: () => [],
  },
  hasInbox: {
    type: Boolean,
    default: false,
  },
});

const templateId = defineModel('templateId', {
  type: [Number, String],
  default: null,
});
const processedParams = defineModel('processedParams', {
  type: Object,
  default: () => ({}),
});

const { t } = useI18n();

const quickVariables = [
  { label: 'Primeiro nome', value: '{{contact.first_name}}' },
  { label: 'Nome completo', value: '{{contact.name}}' },
  { label: 'Telefone', value: '{{contact.phone_number}}' },
  {
    label: 'Valor liberado',
    value: '{{contact.custom_attribute.valor_liberado_total}}',
  },
  {
    label: 'Link individual',
    value: '{{contact.custom_attribute.link_individual}}',
  },
];

const templateOptions = computed(() =>
  props.templates.map(template => ({
    value: getTemplateKey(template),
    label: `${template.name.replace(/_/g, ' ')} (${template.language})`,
  }))
);

const emptyState = computed(() =>
  props.hasInbox
    ? t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.NO_TEMPLATES')
    : t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.EMPTY_STATE')
);

const selectedTemplate = computed(
  () =>
    props.templates.find(
      template => getTemplateKey(template) === templateId.value
    ) ?? null
);

const headerComponent = computed(() =>
  selectedTemplate.value
    ? findComponentByType(selectedTemplate.value, COMPONENT_TYPES.HEADER)
    : null
);

const headerFormat = computed(() => {
  const format = headerComponent.value?.format ?? '';
  return format.charAt(0) + format.slice(1).toLowerCase();
});

const hasMediaHeader = computed(() =>
  MEDIA_FORMATS.includes(headerComponent.value?.format)
);

const isDocumentHeader = computed(
  () => headerComponent.value?.format === 'DOCUMENT'
);

// Static buttons leave holes (or persisted nulls) in the parameter array.
const buttonIndexes = computed(() =>
  (processedParams.value.buttons ?? []).flatMap((button, index) =>
    button ? [index] : []
  )
);

const handleTemplateChange = value => {
  templateId.value = value;
  const template = props.templates.find(item => getTemplateKey(item) === value);
  processedParams.value = template ? buildTemplateParameters(template) : {};
};

const updateHeaderParam = (key, value) => {
  processedParams.value.header = {
    ...processedParams.value.header,
    [key]: value,
  };
};

const appendVariable = (section, key, value) => {
  if (section === 'button') {
    const current = processedParams.value.buttons[key]?.parameter || '';
    processedParams.value.buttons[key].parameter = `${current}${value}`;
    return;
  }
  const current = processedParams.value[section]?.[key] || '';
  processedParams.value[section][key] = `${current}${value}`;
};
</script>

<template>
  <div class="flex flex-col gap-1">
    <label
      for="campaign-template"
      class="mb-0.5 text-heading-3 text-n-slate-12"
    >
      {{ t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.SELECT.LABEL') }}
    </label>
    <ComboBox
      id="campaign-template"
      :model-value="templateId"
      :options="templateOptions"
      :placeholder="t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.SELECT.PLACEHOLDER')"
      :empty-state="emptyState"
      @update:model-value="handleTemplateChange"
    />
  </div>

  <div v-if="hasMediaHeader" class="flex flex-col gap-2">
    <label class="mb-0.5 text-heading-3 text-n-slate-12">
      {{ t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.HEADER_LABEL') }}
    </label>
    <Input
      :model-value="processedParams.header?.media_url ?? ''"
      type="url"
      :message="
        isValidTemplateMediaUrl(processedParams.header?.media_url)
          ? ''
          : t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.INVALID_MEDIA_URL')
      "
      :message-type="
        isValidTemplateMediaUrl(processedParams.header?.media_url)
          ? 'info'
          : 'error'
      "
      :placeholder="
        t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.HEADER_PLACEHOLDER', {
          type: headerFormat,
        })
      "
      @update:model-value="updateHeaderParam('media_url', $event)"
    />
    <Input
      v-if="isDocumentHeader"
      :model-value="processedParams.header?.media_name ?? ''"
      :placeholder="
        t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.DOCUMENT_NAME_PLACEHOLDER')
      "
      @update:model-value="updateHeaderParam('media_name', $event)"
    />
  </div>

  <div v-else-if="processedParams.header" class="flex flex-col gap-2">
    <label class="mb-0.5 text-heading-3 text-n-slate-12">
      {{ t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.HEADER_LABEL') }}
    </label>
    <div v-for="(value, key) in processedParams.header" :key="`header-${key}`">
      <Input
        v-model="processedParams.header[key]"
        :placeholder="t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.VARIABLE_PLACEHOLDER', { variable: key })"
      />
      <div class="flex flex-wrap gap-1 pt-1">
        <button
          v-for="variable in quickVariables"
          :key="`header-${key}-${variable.value}`"
          type="button"
          class="px-2 py-1 text-xs rounded border border-n-slate-5 text-n-slate-11 hover:bg-n-alpha-2"
          @click="appendVariable('header', key, variable.value)"
        >{{ variable.label }}</button>
      </div>
    </div>
  </div>

  <div v-if="processedParams.body" class="flex flex-col gap-2">
    <label class="mb-0.5 text-heading-3 text-n-slate-12">
      {{ t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.BODY_LABEL') }}
    </label>
    <div v-for="(value, key) in processedParams.body" :key="`body-${key}`">
      <Input
        v-model="processedParams.body[key]"
        :placeholder="t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.VARIABLE_PLACEHOLDER', { variable: key })"
      />
      <div class="flex flex-wrap gap-1 pt-1">
        <button
          v-for="variable in quickVariables"
          :key="`body-${key}-${variable.value}`"
          type="button"
          class="px-2 py-1 text-xs rounded border border-n-slate-5 text-n-slate-11 hover:bg-n-alpha-2"
          @click="appendVariable('body', key, variable.value)"
        >{{ variable.label }}</button>
      </div>
    </div>
  </div>

  <div v-if="processedParams.buttons" class="flex flex-col gap-2">
    <label class="mb-0.5 text-heading-3 text-n-slate-12">
      {{ t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.BUTTONS_LABEL') }}
    </label>
    <div v-for="index in buttonIndexes" :key="`button-${index}`">
      <Input
        v-model="processedParams.buttons[index].parameter"
        :placeholder="t('CAMPAIGN.WHATSAPP.FORM.TEMPLATE.BUTTON_PLACEHOLDER', { index: index + 1 })"
      />
      <div class="flex flex-wrap gap-1 pt-1">
        <button
          v-for="variable in quickVariables"
          :key="`button-${index}-${variable.value}`"
          type="button"
          class="px-2 py-1 text-xs rounded border border-n-slate-5 text-n-slate-11 hover:bg-n-alpha-2"
          @click="appendVariable('button', index, variable.value)"
        >{{ variable.label }}</button>
      </div>
    </div>
  </div>
</template>
