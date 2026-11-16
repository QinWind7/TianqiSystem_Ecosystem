<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { RouterLink, useRouter } from 'vue-router'

import NotificationBell from '@/components/notification/NotificationBell.vue'
import ThemeSwitcher from '@/components/ThemeSwitcher.vue'
import HudIcon from '@/components/ui/HudIcon.vue'
import { useClickOutside } from '@/composables/useClickOutside'
import { useTheme } from '@/composables/useTheme'
import { useUnreadStore } from '@/stores/unread'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()
const unreadStore = useUnreadStore()
const { cloudNotice } = useTheme()

const keyword = ref('')
const menuOpen = ref(false)
const menuRef = ref<HTMLElement | null>(null)
// 手机端搜索框默认收起，点放大镜后再展开
const mobileSearchOpen = ref(false)
const mobileSearchInput = ref<HTMLInputElement | null>(null)

const avatarText = computed(() => (userStore.displayName || '天').slice(0, 1))

useClickOutside(menuRef, () => {
  menuOpen.value = false
})

async function toggleMobileSearch(): Promise<void> {
  mobileSearchOpen.value = !mobileSearchOpen.value
  if (mobileSearchOpen.value) {
    await nextTick()
    mobileSearchInput.value?.focus()
  }
}

function onAvatarClick(): void {
  mobileSearchOpen.value = false
  menuOpen.value = !menuOpen.value
  // 打开菜单时顺带刷新一次成长属性，避免长时间挂机后等级/经验过期
  if (menuOpen.value) userStore.loadStatus()
}

function onSearch(): void {
  const value = keyword.value.trim()
  mobileSearchOpen.value = false
  router.push({ name: 'home', query: value ? { search: value } : {} })
}

/** 顶部「返回主界面」：无论当前在哪一页都回到首页。 */
function goHome(): void {
  router.push({ name: 'home' })
}

async function onLogout(): Promise<void> {
  menuOpen.value = false
  await userStore.logout()
  router.push({ name: 'home' })
}
</script>

<template>
  <div class="relative min-h-screen bg-bg">
    <header class="sticky top-0 z-40 border-b border-border bg-surface/95 backdrop-blur">
      <div class="mx-auto max-w-7xl px-4">
        <div class="topbar-row flex h-14 items-center gap-2 sm:h-16">
          <RouterLink to="/" class="topbar-logo flex shrink-0 items-center gap-2" aria-label="天启系统首页">
            <span
              class="grid h-6 w-6 place-items-center rounded-[4px] bg-primary font-mono text-[11px] font-bold text-white"
            >
              天
            </span>
            <span class="topbar-logo-text text-base font-bold tracking-[0.18em] text-text sm:text-lg">
              天启系统
            </span>
            <span
              class="ml-1 hidden items-center gap-1.5 rounded-[4px] border border-primary/25 bg-primary-soft px-2 py-1 font-mono text-[9px] tracking-[0.12em] text-primary sm:flex"
              title="服务状态"
            >
              <span class="status-dot h-1.5 w-1.5 rounded-full bg-emerald-500" aria-hidden="true" />
              APOCALYPSE SYSTEM
            </span>
          </RouterLink>

          <!-- 全局搜索：≥md 时与 Logo 同一行；手机端收起为放大镜按钮 -->
          <form class="hidden min-w-0 flex-1 md:block" @submit.prevent="onSearch">
            <input
              v-model="keyword"
              type="search"
              placeholder="搜索帖子 / 关键词…"
              class="cute-input py-2"
            />
          </form>

        <button
          type="button"
          class="topbar-icon grid h-10 w-10 shrink-0 place-items-center rounded-md border border-border bg-surface-2 font-mono text-[11px] text-text transition hover:shadow-card md:hidden"
          title="搜索"
          :aria-expanded="mobileSearchOpen"
          @click="toggleMobileSearch"
        >
          搜索
        </button>

        <button
          type="button"
          class="topbar-icon cute-btn shrink-0 border border-border bg-surface-2 px-3 text-text hover:shadow-card sm:px-4"
          title="返回主界面"
          @click="goHome"
        >
          <span class="font-mono text-[11px] tracking-[0.08em]">首页</span>
        </button>

        <ThemeSwitcher />

        <template v-if="userStore.isLoggedIn">
          <!-- 手动刷新：方便手机端随时拉取最新未读数 -->
          <button
            type="button"
            class="topbar-icon grid h-10 w-10 shrink-0 place-items-center rounded-md border border-border bg-surface-2 text-base text-text transition hover:shadow-card"
            title="刷新消息"
            @click="unreadStore.refresh()"
          >
            <span
              class="inline-block transition-transform"
              :class="{ 'animate-spin': unreadStore.refreshing }"
              aria-hidden="true"
            >
              ↻
            </span>
          </button>

          <NotificationBell />

          <div ref="menuRef" class="relative">
            <button
              type="button"
              class="avatar-trigger flex items-center gap-2 rounded-md border border-border bg-surface-2 px-2 py-1.5 transition hover:border-primary/40 hover:shadow-card"
              @click="onAvatarClick"
            >
              <span
                v-if="userStore.status"
                class="hidden shrink-0 items-center gap-1 rounded-[4px] border border-primary/30 bg-primary-soft px-2 py-1 font-mono text-[10px] font-semibold tracking-wide text-primary sm:flex"
              >
                LV.{{ userStore.status.level }}
                <span class="text-primary/30" aria-hidden="true">|</span>
                EXP: {{ userStore.status.exp }}
              </span>
              <img
                v-if="userStore.avatar"
                :src="userStore.avatar"
                :alt="userStore.displayName"
                class="h-7 w-7 rounded-full object-cover"
              />
              <span
                v-else
                class="avatar-fallback grid h-7 w-7 place-items-center rounded-full bg-primary-soft text-xs font-bold text-text"
              >
                {{ avatarText }}
              </span>
              <span class="avatar-name hidden max-w-[8rem] truncate text-sm text-text sm:inline">
                {{ userStore.displayName }}
              </span>
              <span class="avatar-caret text-xs text-text-muted">▾</span>
            </button>

            <Transition
              enter-active-class="transition duration-150 ease-out"
              enter-from-class="opacity-0 -translate-y-1"
              leave-active-class="transition duration-100 ease-in"
              leave-to-class="opacity-0 -translate-y-1"
            >
              <div
                v-if="menuOpen"
                class="topbar-menu absolute right-0 mt-2 w-60 overflow-hidden rounded-[4px] border border-border bg-surface p-1 shadow-card"
              >
                <div class="border-b border-border px-3 py-2.5">
                  <p class="truncate text-sm font-semibold text-text">{{ userStore.displayName }}</p>
                  <p class="mt-0.5 font-mono text-[11px] tracking-wide text-text-muted">
                    LV.{{ userStore.status?.level ?? userStore.user?.level ?? 1 }}
                    <template v-if="userStore.status">
                      · EXP {{ userStore.status.exp }}/{{ userStore.status.exp_max }}
                    </template>
                  </p>
                </div>
                <RouterLink
                  v-if="userStore.user"
                  :to="{ name: 'user-profile', params: { id: userStore.user.id } }"
                  class="flex items-center gap-2.5 rounded-[2px] px-2.5 py-2 text-xs text-text transition hover:bg-primary-soft"
                  @click="menuOpen = false"
                >
                  <HudIcon name="profile" :size="14" class="shrink-0 text-primary" />
                  <span>宿主档案</span>
                  <span class="ml-auto font-mono text-[9px] tracking-[0.12em] text-text-muted">
                    PROFILE
                  </span>
                </RouterLink>
                <RouterLink
                  :to="{ name: 'chat' }"
                  class="flex items-center gap-2.5 rounded-[2px] px-2.5 py-2 text-xs text-text transition hover:bg-primary-soft"
                  @click="menuOpen = false"
                >
                  <HudIcon name="chat" :size="14" class="shrink-0 text-primary" />
                  <span>加密信道</span>
                  <span class="ml-auto font-mono text-[9px] tracking-[0.12em] text-text-muted">
                    COMM LINK
                  </span>
                </RouterLink>
                <RouterLink
                  :to="{ name: 'my-friends' }"
                  class="flex items-center gap-2.5 rounded-[2px] px-2.5 py-2 text-xs text-text transition hover:bg-primary-soft"
                  @click="menuOpen = false"
                >
                  <HudIcon name="allies" :size="14" class="shrink-0 text-primary" />
                  <span>共生契者</span>
                  <span class="ml-auto font-mono text-[9px] tracking-[0.12em] text-text-muted">
                    ALLIES
                  </span>
                </RouterLink>
                <RouterLink
                  :to="{ name: 'my-fans' }"
                  class="flex items-center gap-2.5 rounded-[2px] px-2.5 py-2 text-xs text-text transition hover:bg-primary-soft"
                  @click="menuOpen = false"
                >
                  <HudIcon name="followers" :size="14" class="shrink-0 text-primary" />
                  <span>追随者</span>
                  <span class="ml-auto font-mono text-[9px] tracking-[0.12em] text-text-muted">
                    FOLLOWERS
                  </span>
                </RouterLink>
                <button
                  type="button"
                  class="mt-1 flex w-full items-center gap-2.5 rounded-[2px] border-t border-border px-2.5 py-2.5 text-left font-mono text-[11px] tracking-wide text-primary transition hover:bg-primary-soft"
                  @click="onLogout"
                >
                  <HudIcon name="logout" :size="14" class="shrink-0" />
                  <span>[ 强制断开连接 ]</span>
                </button>
              </div>
            </Transition>
          </div>
        </template>
        <template v-else>
          <div class="flex shrink-0 items-center gap-2">
            <RouterLink
              to="/login"
              class="cute-btn border border-border bg-surface-2 text-text hover:shadow-card"
            >
              登录
            </RouterLink>
            <RouterLink to="/register" class="cute-btn bg-primary text-white hover:shadow-card">
              注册
            </RouterLink>
          </div>
        </template>
        </div>

        <!-- 手机端：点放大镜后在顶栏下方展开搜索框 -->
        <form v-if="mobileSearchOpen" class="pb-2 md:hidden" @submit.prevent="onSearch">
          <input
            ref="mobileSearchInput"
            v-model="keyword"
            type="search"
            placeholder="搜索帖子 / 关键词…"
            class="cute-input py-2"
          />
        </form>
      </div>
    </header>

    <!-- 全局欢迎横幅：站外入口 + 站内公告都收进这里，避免挤占导航栏 -->
    <section class="mx-auto max-w-7xl px-4 pt-4">
      <div class="relative overflow-hidden rounded-card border border-border shadow-card">
        <div class="absolute inset-0" :style="{ background: 'var(--gradient-hero)' }" aria-hidden="true" />

        <div class="relative flex flex-col gap-3 px-4 py-4 sm:px-6 sm:py-5 lg:flex-row lg:items-center lg:gap-6">
          <div class="min-w-0 lg:flex-1">
            <p class="font-mono text-[9px] tracking-[0.18em] text-primary/70">// SYSTEM BROADCAST</p>
            <p class="mt-1 text-lg font-bold text-text sm:text-xl">欢迎来到天启系统</p>
            <p class="mt-1 text-xs text-text-muted sm:text-sm">
              宿主成长数据与移动端实时同步，请勿偏离既定因果线
            </p>
          </div>

          <!-- 站外入口：系统流小说快捷通道 -->
          <div class="flex flex-wrap items-center gap-2">
            <a
              href="https://www.qidian.com/search?kw=系统流"
              target="_blank"
              rel="noopener noreferrer"
              class="quick-link group inline-flex items-center gap-2 rounded-lg border border-border bg-surface px-3 py-2 text-sm font-medium text-text shadow-card transition hover:-translate-y-0.5 hover:border-primary"
              title="起点系统流（新标签页打开）"
            >
              <span
                class="grid h-8 w-8 place-items-center rounded-[4px] bg-primary-soft font-mono text-[10px] font-semibold text-primary"
              >
                01
              </span>
              <span>起点系统流</span>
              <span class="text-xs text-text-muted transition group-hover:translate-x-0.5">↗</span>
            </a>
            <a
              href="https://fanqienovel.com/search?q=%E7%B3%BB%E7%BB%9F"
              target="_blank"
              rel="noopener noreferrer"
              class="quick-link group inline-flex items-center gap-2 rounded-lg border border-border bg-surface px-3 py-2 text-sm font-medium text-text shadow-card transition hover:-translate-y-0.5 hover:border-primary"
              title="番茄无限流（新标签页打开）"
            >
              <span
                class="grid h-8 w-8 place-items-center rounded-[4px] bg-primary-soft font-mono text-[10px] font-semibold text-primary"
              >
                02
              </span>
              <span>番茄无限流</span>
              <span class="text-xs text-text-muted transition group-hover:translate-x-0.5">↗</span>
            </a>
          </div>

          <!-- 站内公告 -->
          <div class="rounded-lg border border-border bg-surface px-3.5 py-2.5 lg:w-[320px] lg:shrink-0">
            <p class="flex items-center gap-1.5 text-xs font-semibold text-text">
              <span class="font-mono text-[10px] text-primary">// SYSTEM BROADCAST</span> 系统广播
            </p>
            <p class="mt-1 line-clamp-3 text-xs leading-relaxed text-text-muted">
              【警告】请各位宿主遵守因果律法则。严禁私自篡改主线任务，违者将被抹杀。可在【异常反馈】区提交系统
              Bug。
            </p>
          </div>
        </div>
      </div>
    </section>

    <main class="mx-auto max-w-7xl px-4 py-5 sm:py-6">
      <router-view />
    </main>

    <footer class="mx-auto max-w-7xl px-4 pb-10 pt-4 text-center">
      <span class="font-mono text-[10px] tracking-[0.14em] text-text-muted">
        // APOCALYPSE SYSTEM · ONLINE
      </span>
    </footer>

    <!-- 换肤云端保存失败提示 -->
    <Transition
      enter-active-class="transition duration-200 ease-out"
      enter-from-class="opacity-0 translate-y-2"
      leave-active-class="transition duration-150 ease-in"
      leave-to-class="opacity-0 translate-y-2"
    >
      <div
        v-if="cloudNotice"
        class="fixed bottom-6 left-1/2 z-50 -translate-x-1/2 rounded-full border border-border bg-surface px-4 py-2 text-sm text-text shadow-card"
      >
        🎨 {{ cloudNotice }}
      </div>
    </Transition>
  </div>
</template>
