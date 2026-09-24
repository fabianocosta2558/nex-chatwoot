<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';

defineProps({
  buttonLabel: {
    type: String,
    required: true,
  },
  confirmLabel: {
    type: String,
    default: '',
  },
  variant: {
    type: String,
    default: 'solid',
  },
  color: {
    type: String,
    default: 'blue',
  },
  showActions: {
    type: Boolean,
    default: true,
  },
  isDisabled: {
    type: Boolean,
    default: false,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['confirm']);

const scheduledAt = defineModel({ type: String, default: '' });
const deliverySettings = defineModel('deliverySettings', {
  type: Object,
  default: () => ({
    mode: 'distributed',
    daily_limit: 100,
    window_start: '08:00',
    window_end: '18:00',
    time_zone: 'America/Sao_Paulo',
  }),
});

const { t } = useI18n();

const popoverRef = ref(null);

const minDateTime = computed(() => {
  const now = new Date();
  return new Date(now.getTime() - now.getTimezoneOffset() * 60000)
    .toISOString()
    .slice(0, 16);
});

const handleConfirm = () => {
  popoverRef.value.hide();
  emit('confirm');
};
</script>

<template>
  <Popover ref="popoverRef">
    <Button
      size="sm"
      :variant="variant"
      :color="color"
      :label="buttonLabel"
      :disabled="isDisabled"
    />
    <template #content="{ hide }">
      <div class="flex flex-col gap-3 p-4 w-72">
        <Input
          v-model="scheduledAt"
          type="datetime-local"
          :min="minDateTime"
          :label="t('CAMPAIGN.WHATSAPP.FORM.SCHEDULE_POPOVER.LABEL')"
        />
        <div class="pt-2 border-t border-n-slate-4">
          <p class="mb-2 text-sm font-medium text-n-slate-12">Envio distribuído</p>
          <label class="block mb-1 text-xs text-n-slate-11">Limite por dia</label>
          <select v-model.number="deliverySettings.daily_limit" class="w-full px-2 py-2 mb-3 border rounded bg-n-solid-1 border-n-slate-5 text-n-slate-12">
            <option :value="100">100 mensagens</option>
            <option :value="200">200 mensagens</option>
            <option :value="300">300 mensagens</option>
          </select>
          <div class="grid grid-cols-2 gap-2">
            <Input v-model="deliverySettings.window_start" type="time" label="Início" />
            <Input v-model="deliverySettings.window_end" type="time" label="Fim" />
          </div>
          <p class="mt-2 text-xs text-n-slate-10">Os destinatários serão distribuídos dentro dessa janela, no horário de Brasília.</p>
        </div>
        <div v-if="showActions" class="flex items-center justify-between gap-3">
          <Button
            variant="faded"
            color="slate"
            size="sm"
            class="w-full"
            :label="t('CAMPAIGN.WHATSAPP.FORM.SCHEDULE_POPOVER.CANCEL')"
            @click="hide"
          />
          <Button
            size="sm"
            class="w-full"
            :label="confirmLabel"
            :is-loading="isLoading"
            :disabled="isLoading || scheduledAt < minDateTime"
            @click="handleConfirm"
          />
        </div>
      </div>
    </template>
  </Popover>
</template>
