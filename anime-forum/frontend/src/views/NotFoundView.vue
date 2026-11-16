<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>

<template>
  <div class="relative flex min-h-screen items-center justify-center overflow-hidden px-4 text-center">
    <div class="absolute inset-0 -z-10" :style="{ background: 'var(--gradient-hero)' }" />

    <div class="cute-card hud-corners animate-fade-in-up max-w-md rounded-[4px] p-8 sm:p-10">
      <p class="font-mono text-[10px] tracking-[0.2em] text-primary">// SIGNAL LOST</p>
      <h1 class="mt-4 font-mono text-4xl font-bold tracking-[0.12em] text-primary">404</h1>
      <p class="mt-3 text-base font-semibold text-text">该节点不存在或已从因果线中移除</p>
      <p class="mt-1 font-mono text-[11px] text-text-muted">ERR_ROUTE_NOT_FOUND</p>
      <RouterLink to="/" class="cute-btn mt-6 bg-primary font-semibold text-white hover:shadow-card">
        [ 返回任务大厅 ]
      </RouterLink>
    </div>
  </div>
</template>
