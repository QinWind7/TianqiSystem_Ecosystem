<script setup lang="ts">
import { RouterLink } from 'vue-router'
</script>

<template>
  <div class="relative flex min-h-screen items-center justify-center overflow-hidden px-4 py-10">
    <!-- 渐变背景走 --gradient-hero，随主题切换 -->
    <div class="absolute inset-0 -z-10" :style="{ background: 'var(--gradient-hero)' }" />

    <div class="w-full max-w-md">
      <div class="cute-card animate-fade-in-up p-7 sm:p-9">
        <div class="mb-6 text-center">
          <RouterLink to="/" class="inline-flex items-center gap-2 text-2xl font-bold text-primary">
            <span
              class="grid h-8 w-8 place-items-center rounded-[4px] bg-primary font-mono text-sm font-bold text-white"
            >
              天
            </span>
            <span class="tracking-[0.12em]">天启系统</span>
          </RouterLink>
          <p class="mt-2 font-mono text-[10px] tracking-[0.18em] text-text-muted">
            APOCALYPSE SYSTEM · HOST TERMINAL
          </p>
        </div>
        <router-view />
      </div>
      <div class="mt-5 text-center">
        <RouterLink
          to="/"
          class="text-sm text-text-muted transition hover:text-primary"
        >
          ← 返回任务大厅
        </RouterLink>
      </div>
    </div>
  </div>
</template>
