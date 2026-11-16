<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { RouterLink, useRouter } from 'vue-router'

import {
  deleteReadNotifications,
  fetchNotifications,
  markAllNotificationsRead,
  markNotificationRead,
} from '@/api/notification'
import { acceptFriendRequest, rejectFriendRequest } from '@/api/social'
import type { NotificationItem } from '@/api/types'
import { useClickOutside } from '@/composables/useClickOutside'
import { useUnreadStore } from '@/stores/unread'
import { useUserStore } from '@/stores/user'
import { fromNow } from '@/utils/format'
import HudIcon from '@/components/ui/HudIcon.vue'

const router = useRouter()
const userStore = useUserStore()
// 未读总数由 App.vue 每 15 秒统一轮询，这里只负责展示与本地增减
const unreadStore = useUnreadStore()

const open = ref(false)
const loading = ref(false)
const items = ref<NotificationItem[]>([])
// 正在处理的好友申请通知 id，防止重复点击
const actionBusyId = ref(0)
const clearing = ref(false)

const readCount = computed(() => items.value.filter((item) => item.is_read).length)

const rootRef = ref<HTMLElement | null>(null)

const badge = computed(() => (unreadStore.total > 99 ? '99+' : String(unreadStore.total)))

useClickOutside(rootRef, () => {
  open.value = false
})

async function loadLatest(): Promise<void> {
  if (!userStore.isLoggedIn) return
  loading.value = true
  try {
    const data = await fetchNotifications({ page_size: 8 })
    items.value = data.results
  } catch {
    items.value = []
  } finally {
    loading.value = false
  }
  void unreadStore.refresh()
}

function toggle(): void {
  open.value = !open.value
  if (open.value) void loadLatest()
}

/** 置读：先本地生效，再同步服务端，失败不回滚（下次刷新以服务端为准）。 */
async function markRead(item: NotificationItem): Promise<void> {
  if (item.is_read) return
  item.is_read = true
  unreadStore.decreaseNotifications()
  try {
    await markNotificationRead(item.id)
  } catch {
    // 本地已读态保留
  }
}

/** 点击通知：标记已读，再跳到帖子或对方主页。 */
async function onItemClick(item: NotificationItem): Promise<void> {
  await markRead(item)
  open.value = false
  if (item.post) {
    router.push({ name: 'post-detail', params: { id: item.post } })
  } else if (item.type === 'follow' || item.type === 'friend_request' || item.type === 'friend_accept') {
    router.push({ name: 'user-profile', params: { id: item.actor.id } })
  }
}

/** 铃铛里直接同意 / 拒绝好友申请，免去跳转。 */
async function onFriendAction(item: NotificationItem, accept: boolean): Promise<void> {
  if (!item.friend_request || actionBusyId.value) return
  actionBusyId.value = item.id
  try {
    if (accept) {
      await acceptFriendRequest(item.friend_request)
      item.friend_request_status = 1
    } else {
      await rejectFriendRequest(item.friend_request)
      item.friend_request_status = 2
    }
    await markRead(item)
  } catch {
    // 保持原状态，用户可以再点一次
  } finally {
    actionBusyId.value = 0
  }
}

async function onMarkAll(): Promise<void> {
  if (!unreadStore.notifications) return
  try {
    await markAllNotificationsRead()
    items.value = items.value.map((item) => ({ ...item, is_read: true }))
    unreadStore.clearNotifications()
  } catch {
    // 失败时保持原状态，用户可再点一次
  }
}

/** 清除已读：服务端删除后重新拉列表，未读的不受影响。 */
async function onClearRead(): Promise<void> {
  if (clearing.value) return
  clearing.value = true
  try {
    await deleteReadNotifications()
    await loadLatest()
  } catch {
    // 失败时保持原列表，用户可再点一次
  } finally {
    clearing.value = false
  }
}

function typeIcon(item: NotificationItem): 'like' | 'comment' | 'follow' | 'allies' | 'friend' {
  if (item.type === 'like') return 'like'
  if (item.type === 'comment') return 'comment'
  if (item.type === 'follow') return 'follow'
  if (item.type === 'friend_request') return 'allies'
  return 'friend'
}

function typeText(item: NotificationItem): string {
  if (item.type === 'like') return '赞许了你的指令'
  if (item.type === 'comment') return '回复了你的指令'
  if (item.type === 'follow') return '开始追随你'
  if (item.type === 'friend_request') return '申请建立共生契约'
  return '通过了你的共生申请'
}

watch(
  () => userStore.isLoggedIn,
  (loggedIn) => {
    if (!loggedIn) {
      open.value = false
      items.value = []
    }
  },
)
</script>

<template>
  <div ref="rootRef" class="relative shrink-0">
    <button
      type="button"
      class="topbar-icon relative grid h-10 w-10 place-items-center rounded-md border border-border bg-surface-2 text-primary transition hover:border-primary/40 hover:shadow-card"
      :aria-expanded="open"
      title="系统日志"
      @click="toggle"
    >
      <HudIcon name="bell" :size="17" />
      <span
        v-if="unreadStore.total > 0"
        class="absolute -right-1 -top-1 grid h-[18px] min-w-[18px] place-items-center rounded-full bg-primary px-1 font-mono text-[9px] font-bold leading-none text-white"
      >
        {{ badge }}
      </span>
    </button>

    <Transition
      enter-active-class="transition duration-150 ease-out"
      enter-from-class="opacity-0 -translate-y-1"
      leave-active-class="transition duration-100 ease-in"
      leave-to-class="opacity-0 -translate-y-1"
    >
      <div
        v-if="open"
        class="bell-panel absolute -right-12 z-50 mt-2 w-[min(20rem,calc(100vw-2rem))] overflow-hidden rounded-none border border-primary/40 bg-surface sm:right-0 sm:w-80"
      >
        <div class="flex items-center justify-between gap-2 border-b border-primary/25 px-3 py-2.5">
          <p class="flex min-w-0 items-center gap-1.5 font-mono text-[11px] tracking-[0.06em] text-text">
            <span class="shrink-0 text-primary">// SYSTEM LOGS</span>
            <span class="shrink-0">系统日志</span>
            <span
              v-if="unreadStore.notifications"
              class="ml-1 shrink-0 rounded-[2px] border border-primary/30 bg-primary-soft px-1.5 py-0.5 font-mono text-[9px] text-primary"
            >
              {{ unreadStore.notifications }} 条未读
            </span>
          </p>
          <button
            type="button"
            class="shrink-0 rounded-[2px] px-2 py-1 font-mono text-[10px] text-text-muted transition hover:bg-primary-soft hover:text-primary disabled:opacity-40"
            :disabled="!unreadStore.notifications"
            @click="onMarkAll"
          >
            [ 全部已读 ]
          </button>
        </div>

        <!-- 铃铛红点包含私聊未读，这里给一个直达入口 -->
        <RouterLink
          v-if="unreadStore.messages > 0"
          :to="{ name: 'chat' }"
          class="flex items-center justify-between gap-2 border-b border-primary/20 bg-primary-soft px-3 py-2 font-mono text-[11px] text-text transition hover:text-primary"
          @click="open = false"
        >
          <span class="inline-flex items-center gap-1.5">
            <HudIcon name="chat" :size="12" class="text-primary" />
            {{ unreadStore.messages }} 条加密信道未读
          </span>
          <span class="shrink-0 font-semibold">去查看 →</span>
        </RouterLink>

        <div v-if="loading" class="space-y-2 p-3">
          <div v-for="n in 3" :key="n" class="h-12 animate-pulse rounded-none bg-surface-2" />
        </div>

        <ul v-else-if="items.length" class="max-h-80 overflow-y-auto p-1.5">
          <li v-for="item in items" :key="item.id">
            <!-- 用 div 而不是 button：好友申请那一行里还要嵌「同意 / 拒绝」按钮 -->
            <div
              role="button"
              tabindex="0"
              class="flex w-full cursor-pointer items-start gap-2.5 rounded-[2px] px-2 py-2 text-left transition hover:bg-primary-soft focus:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              :class="item.is_read ? '' : 'bg-surface-2'"
              @click="onItemClick(item)"
              @keydown.enter="onItemClick(item)"
            >
              <img
                v-if="item.actor.avatar"
                :src="item.actor.avatar"
                :alt="item.actor.display_name"
                class="mt-0.5 h-8 w-8 shrink-0 rounded-[2px] object-cover"
              />
              <span
                v-else
                class="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-[2px] bg-primary-soft font-mono text-xs font-bold text-primary"
              >
                {{ (item.actor.display_name || '天').slice(0, 1) }}
              </span>

              <span class="min-w-0 flex-1">
                <span class="block truncate text-xs text-text">
                  <span class="font-semibold">{{ item.actor.display_name }}</span>
                  {{ typeText(item) }}
                </span>
                <span v-if="item.post" class="mt-0.5 block truncate text-[11px] text-text-muted">
                  {{ item.post_title || '（指令已删除）' }}
                </span>
                <span v-else class="mt-0.5 block truncate text-[11px] text-text-muted">
                  点击查阅该宿主档案
                </span>

                <!-- 好友申请：直接在这里同意 / 拒绝 -->
                <span
                  v-if="item.type === 'friend_request'"
                  class="mt-1 flex flex-wrap items-center gap-1.5"
                >
                  <template v-if="item.friend_request_status === 0">
                    <button
                      type="button"
                      class="rounded-[2px] bg-primary px-2.5 py-0.5 text-[10px] font-semibold text-white transition hover:shadow-card disabled:opacity-50"
                      :disabled="actionBusyId === item.id"
                      @click.stop="onFriendAction(item, true)"
                    >
                      同意
                    </button>
                    <button
                      type="button"
                      class="rounded-[2px] border border-border bg-surface px-2.5 py-0.5 text-[10px] text-text-muted transition hover:text-text disabled:opacity-50"
                      :disabled="actionBusyId === item.id"
                      @click.stop="onFriendAction(item, false)"
                    >
                      拒绝
                    </button>
                  </template>
                  <span
                    v-else
                    class="rounded-[2px] border border-border bg-surface-2 px-2 py-0.5 font-mono text-[9px] text-text-muted"
                  >
                    {{ item.friend_request_status === 1 ? '[ 已通过 ]' : '[ 已拒绝 ]' }}
                  </span>
                </span>

                <span class="mt-0.5 flex items-center gap-1 font-mono text-[10px] text-text-muted">
                  <HudIcon :name="typeIcon(item)" :size="10" class="text-primary/70" />
                  {{ fromNow(item.created_at) }}
                </span>
              </span>

              <span v-if="!item.is_read" class="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-primary" />
            </div>
          </li>
        </ul>

        <p
          v-else
          class="px-4 py-8 text-center font-mono text-[11px] tracking-[0.08em] text-text-muted"
        >
          [ 暂无系统广播与指令 ]
        </p>

        <!-- 清除已读：列表底部文字按钮 -->
        <div
          v-if="items.length"
          class="flex items-center justify-between gap-2 border-t border-primary/20 px-3 py-2"
        >
          <span class="font-mono text-[9px] tracking-wide text-text-muted">
            // 最近 {{ items.length }} 条 · 已读 {{ readCount }}
          </span>
          <button
            type="button"
            class="shrink-0 rounded-[2px] px-2 py-1 font-mono text-[10px] text-text-muted transition hover:bg-primary-soft hover:text-primary disabled:cursor-default disabled:opacity-40"
            :disabled="!readCount || clearing"
            @click="onClearRead"
          >
            {{ clearing ? '[ 清除中… ]' : '[ 清除已读 ]' }}
          </button>
        </div>
      </div>
    </Transition>
  </div>
</template>
