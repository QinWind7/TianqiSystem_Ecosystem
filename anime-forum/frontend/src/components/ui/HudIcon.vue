<script setup lang="ts">
withDefaults(
  defineProps<{
    name:
      | 'profile'
      | 'chat'
      | 'allies'
      | 'followers'
      | 'logout'
      | 'bell'
      | 'like'
      | 'comment'
      | 'follow'
      | 'friend'
    size?: number
  }>(),
  { size: 14 },
)
</script>

<template>
  <svg
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.6"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <template v-if="name === 'profile'">
      <circle cx="12" cy="8" r="3.4" />
      <path d="M4.5 20c1.1-3.4 3.8-5 7.5-5s6.4 1.6 7.5 5" />
    </template>
    <template v-else-if="name === 'chat'">
      <path d="M4 5h16v11H9l-4 3v-3H4z" />
      <path d="M8 9h8M8 12.5h5" />
    </template>
    <template v-else-if="name === 'allies'">
      <circle cx="9" cy="8" r="3" />
      <path d="M3 20c.7-3.2 2.7-4.8 6-4.8s5.3 1.6 6 4.8" />
      <path d="M16.5 5.2a2.8 2.8 0 0 1 0 5.6M18 20c-.2-1.5-.7-2.8-1.5-3.8" />
    </template>
    <template v-else-if="name === 'followers'">
      <circle cx="12" cy="8" r="3.2" />
      <path d="M5 20c.9-3.4 3.4-5 7-5s6.1 1.6 7 5" />
      <path d="M18.5 5.5v4M16.5 7.5h4" />
    </template>
    <template v-else-if="name === 'logout'">
      <path d="M12 3.5v8" />
      <path d="M6.4 6.8a8 8 0 1 0 11.2 0" />
    </template>
    <template v-else-if="name === 'bell'">
      <path d="M6.5 9a5.5 5.5 0 0 1 11 0c0 3.7 1.2 5.2 1.2 5.2H5.3S6.5 12.7 6.5 9Z" />
      <path d="M10 17.5a2 2 0 0 0 4 0" />
    </template>
    <template v-else-if="name === 'like'">
      <path d="M12 20s-7-4.4-7-9a4 4 0 0 1 7-2.6A4 4 0 0 1 19 11c0 4.6-7 9-7 9Z" />
    </template>
    <template v-else-if="name === 'comment'">
      <path d="M4.5 5.5h15v10h-9l-4 3v-3h-2z" />
      <path d="M8 9h8M8 12h5" />
    </template>
    <template v-else-if="name === 'follow'">
      <circle cx="10" cy="8" r="3" />
      <path d="M4 20c.8-3.2 3-4.8 6-4.8s5.2 1.6 6 4.8" />
      <path d="M18 8v6M15 11h6" />
    </template>
    <template v-else-if="name === 'friend'">
      <path d="M9.5 14.5 7 17a3.5 3.5 0 0 1-5-5l3-3a3.5 3.5 0 0 1 5 0" />
      <path d="M14.5 9.5 17 7a3.5 3.5 0 0 1 5 5l-3 3a3.5 3.5 0 0 1-5 0" />
      <path d="M9 15l6-6" />
    </template>
  </svg>
</template>
