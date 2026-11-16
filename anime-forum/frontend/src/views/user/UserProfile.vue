<script setup lang="ts">
import { computed, reactive, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import { ApiError } from '@/api/request'
import { sendFriendRequest, toggleFollow } from '@/api/social'
import type { LikedPost, Post, PublicProfile } from '@/api/types'
import { fetchUserLikes, fetchUserPosts, fetchUserProfile, updateMyPrivacy } from '@/api/user'
import PostCard from '@/components/post/PostCard.vue'
import HudIcon from '@/components/ui/HudIcon.vue'
import { useUserStore } from '@/stores/user'
import { compactCount } from '@/utils/format'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()

const PAGE_SIZE = 20

const userId = computed(() => Number(route.params.id))
const isSelf = computed(() => userStore.user?.id === userId.value)

const profile = ref<PublicProfile | null>(null)
const profileLoading = ref(true)
const profileError = ref('')

type TabKey = 'posts' | 'likes'
interface TabState {
  items: (Post | LikedPost)[]
  count: number
  page: number
  loading: boolean
  loaded: boolean
  hidden: boolean
  error: string
}

function emptyTab(): TabState {
  return { items: [], count: 0, page: 0, loading: false, loaded: false, hidden: false, error: '' }
}

const tabs = reactive<Record<TabKey, TabState>>({ posts: emptyTab(), likes: emptyTab() })
const activeTab = ref<TabKey>('posts')

const profileName = computed(() => profile.value?.display_name || profile.value?.username || '天')
const joinedAt = computed(() => (profile.value?.date_joined ?? '').slice(0, 10))

const postsTabLabel = computed(() => (isSelf.value ? '我的执行记录' : '该宿主的执行记录'))
const likesTabLabel = computed(() => (isSelf.value ? '我的赞许记录' : '该宿主的赞许记录'))
const emptyText = computed(() => {
  if (isSelf.value) {
    return activeTab.value === 'posts' ? '当前没有执行记录' : '当前没有赞许记录'
  }
  return activeTab.value === 'posts' ? '该宿主没有执行记录' : '该宿主没有赞许记录'
})

const privacySaving = ref(false)
const privacyError = ref('')

// 社交操作（关注 / 好友申请）共用一套忙碌与错误状态，避免同时点两次
const socialBusy = ref(false)
const socialError = ref('')

function ensureLogin(): boolean {
  if (userStore.isLoggedIn) return true
  router.push({ name: 'login', query: { redirect: route.fullPath } })
  return false
}

async function onToggleFollow(): Promise<void> {
  if (!profile.value || socialBusy.value) return
  if (!ensureLogin()) return
  socialBusy.value = true
  socialError.value = ''
  try {
    const result = await toggleFollow(profile.value.id)
    profile.value.is_following = result.following
    profile.value.follower_count = result.follower_count
  } catch (error) {
    socialError.value = error instanceof Error ? error.message : '操作失败，请稍后重试'
  } finally {
    socialBusy.value = false
  }
}

async function onSendFriendRequest(): Promise<void> {
  if (!profile.value || socialBusy.value) return
  if (!ensureLogin()) return
  socialBusy.value = true
  socialError.value = ''
  try {
    const result = await sendFriendRequest(profile.value.id)
    // 对方此前已申请过我时，后端会自动互相通过（status = 1）
    profile.value.is_friend = result.status === 1
    profile.value.has_pending_request = result.status === 0
  } catch (error) {
    socialError.value = error instanceof Error ? error.message : '申请发送失败，请稍后重试'
  } finally {
    socialBusy.value = false
  }
}

/** 已是好友 → 直接跳到私聊页并打开与该用户的会话。 */
function onChat(): void {
  if (!profile.value) return
  router.push({ name: 'chat', query: { user: String(profile.value.id) } })
}

async function loadProfile(): Promise<void> {
  profileLoading.value = true
  profileError.value = ''
  profile.value = null
  try {
    profile.value = await fetchUserProfile(userId.value)
  } catch (error) {
    profileError.value =
      error instanceof ApiError && error.status === 404
        ? '该宿主档案不存在或已注销'
        : error instanceof Error
          ? error.message
          : '资料加载失败'
  } finally {
    profileLoading.value = false
  }
}

async function loadTab(key: TabKey, reset = false): Promise<void> {
  const state = tabs[key]
  if (state.loading) return
  if (!reset && state.loaded) return

  if (reset) {
    state.items = []
    state.count = 0
    state.page = 0
    state.loaded = false
  }

  state.loading = true
  state.error = ''
  state.hidden = false
  const nextPage = state.page + 1

  try {
    const data =
      key === 'posts'
        ? await fetchUserPosts(userId.value, { page: nextPage, page_size: PAGE_SIZE })
        : await fetchUserLikes(userId.value, { page: nextPage, page_size: PAGE_SIZE })
    state.items = reset ? data.results : [...state.items, ...data.results]
    state.count = data.count
    state.page = nextPage
    state.loaded = true
  } catch (error) {
    if (error instanceof ApiError && error.status === 403) {
      // 对方开启了隐私开关：展示可爱提示，而不是错误弹窗
      state.hidden = true
      state.items = []
      state.count = 0
      state.loaded = true
    } else {
      state.error = error instanceof Error ? error.message : '加载失败，请稍后重试'
    }
  } finally {
    state.loading = false
  }
}

function switchTab(key: TabKey): void {
  if (activeTab.value === key) return
  activeTab.value = key
  void loadTab(key)
}

async function onPrivacyChange(field: 'hide_posts' | 'hide_likes', value: boolean): Promise<void> {
  if (!profile.value || privacySaving.value) return
  privacySaving.value = true
  privacyError.value = ''
  try {
    const updated = await updateMyPrivacy({ [field]: value })
    userStore.setUser(updated)
    profile.value.hide_posts = updated.hide_posts
    profile.value.hide_likes = updated.hide_likes
  } catch (error) {
    // 回滚 UI 到服务端的真实状态
    profile.value[field] = !value
    privacyError.value = error instanceof Error ? error.message : '保存失败，请稍后重试'
  } finally {
    privacySaving.value = false
  }
}

watch(
  userId,
  () => {
    tabs.posts = emptyTab()
    tabs.likes = emptyTab()
    activeTab.value = 'posts'
    privacyError.value = ''
    socialError.value = ''
    void loadProfile()
    // 两个 Tab 都预取一次：资料卡上的「发帖 / 点赞」统计才准确
    void loadTab('posts')
    void loadTab('likes')
  },
  { immediate: true },
)
</script>

<template>
  <div class="mx-auto max-w-4xl space-y-4">
    <!-- 资料卡 -->
    <div v-if="profileLoading" class="cute-card h-40 animate-pulse" />

    <div v-else-if="profileError || !profile" class="cute-card flex flex-col items-center gap-3 px-6 py-14 text-center">
      <div class="font-mono text-2xl tracking-[0.2em] text-primary">[ ! ]</div>
      <p class="text-base font-semibold text-text">节点离线 · 无法读取宿主档案</p>
      <p class="text-sm text-text-muted">{{ profileError || '该因果线已被回收' }}</p>
      <button type="button" class="cute-btn bg-primary text-white" @click="loadProfile">重新连接</button>
    </div>

    <template v-else>
      <section class="cute-card hud-corners relative overflow-hidden p-5 sm:p-6">
        <div class="absolute inset-x-0 top-0 h-20 opacity-70" :style="{ background: 'var(--gradient-hero)' }" />

        <div class="relative flex flex-col items-center gap-4 sm:flex-row sm:items-end">
          <div class="relative shrink-0">
            <img
              v-if="profile.avatar"
              :src="profile.avatar"
              :alt="profileName"
              class="h-20 w-20 rounded-full border-4 border-surface object-cover shadow-card"
            />
            <span
              v-else
              class="grid h-20 w-20 place-items-center rounded-full border-4 border-surface bg-primary-soft text-2xl font-bold text-text shadow-card"
            >
              {{ profileName.slice(0, 1) }}
            </span>

            <!-- 他人主页：头像右上角关注按钮 -->
            <button
              v-if="!isSelf"
              type="button"
              class="absolute -right-2 -top-2 rounded-full px-2.5 py-1 text-[11px] font-semibold shadow-card transition disabled:opacity-60"
              :class="
                profile.is_following
                  ? 'border border-border bg-surface text-text-muted hover:text-text'
                  : 'bg-primary text-white hover:-translate-y-0.5'
              "
              :disabled="socialBusy"
              @click="onToggleFollow"
            >
              {{ profile.is_following ? '已关注' : '＋ 关注' }}
            </button>
          </div>

          <div class="min-w-0 flex-1 text-center sm:text-left">
            <div class="flex flex-wrap items-center justify-center gap-2 sm:justify-start">
              <h1 class="truncate text-xl font-bold text-text">{{ profileName }}</h1>
              <span class="rounded-full bg-surface-2 px-2 py-0.5 text-[11px] text-text-muted">
                Lv.{{ profile.level }}
              </span>
              <span
                v-if="profile.is_staff"
                class="rounded-[2px] border border-primary/30 bg-primary-soft px-2 py-0.5 font-mono text-[10px] tracking-wide text-primary"
              >
                系统管理员
              </span>
              <span
                v-if="isSelf"
                class="rounded-[2px] border border-border bg-surface-2 px-2 py-0.5 font-mono text-[10px] tracking-wide text-text-muted"
              >
                [ 当前宿主标识 ]
              </span>
            </div>
            <p class="mt-1 text-xs text-text-muted">@{{ profile.username }} · 加入于 {{ joinedAt }}</p>

            <!-- 他人主页：昵称下方的加好友 / 私聊入口 -->
            <div
              v-if="!isSelf"
              class="mt-2 flex flex-wrap items-center justify-center gap-2 sm:justify-start"
            >
              <button
                v-if="profile.is_friend"
                type="button"
                class="cute-btn inline-flex items-center gap-1.5 bg-primary px-3 py-1.5 text-xs text-white hover:shadow-card"
                @click="onChat"
              >
                <HudIcon name="chat" :size="13" />
                建立加密信道
              </button>
              <button
                v-else-if="profile.has_pending_request"
                type="button"
                class="cute-btn cursor-default border border-border bg-surface-2 px-3 py-1.5 font-mono text-[11px] text-text-muted"
                disabled
              >
                [ 申请待审 ]
              </button>
              <button
                v-else
                type="button"
                class="cute-btn inline-flex items-center gap-1.5 border border-border bg-surface-2 px-3 py-1.5 text-xs text-text hover:shadow-card disabled:opacity-60"
                :disabled="socialBusy"
                @click="onSendFriendRequest"
              >
                <HudIcon name="allies" :size="13" class="text-primary" />
                建立共生契约
              </button>
            </div>
            <p v-if="socialError" class="mt-1 font-mono text-[11px] text-primary">
              // ERROR: {{ socialError }}
            </p>

            <p class="mt-2 line-clamp-2 text-sm text-text">
              {{ profile.bio || '该宿主尚未写入因果线简介' }}
            </p>
          </div>

          <!-- 终端式统计 -->
          <div
            class="flex shrink-0 flex-wrap items-center justify-center gap-x-2 gap-y-1 font-mono text-[10px] tracking-wide text-text-muted sm:justify-end"
          >
            <span>[ POSTS: <span class="text-text">{{ compactCount(tabs.posts.count) }}</span> ]</span>
            <span class="text-border">//</span>
            <span>[ LIKES: <span class="text-text">{{ compactCount(tabs.likes.count) }}</span> ]</span>
            <span class="text-border">//</span>
            <span>[ FOLLOWERS: <span class="text-text">{{ compactCount(profile.follower_count) }}</span> ]</span>
            <span class="text-border">//</span>
            <span>[ POINTS: <span class="text-text">{{ compactCount(profile.points) }}</span> ]</span>
          </div>
        </div>
      </section>

      <!-- 自己的主页：数据节点权限 -->
      <section v-if="isSelf" class="cute-card hud-corners p-4 sm:p-5">
        <div class="mb-3 flex items-center justify-between gap-2">
          <div>
            <p class="font-mono text-xs tracking-[0.08em] text-text">[ 数据节点权限 ]</p>
            <p class="mt-1 text-[11px] text-text-muted">
              隐藏后，其他宿主将无法查阅你的因果线。
            </p>
          </div>
          <span v-if="privacySaving" class="shrink-0 font-mono text-[10px] text-text-muted">保存中…</span>
        </div>

        <div class="grid gap-2 sm:grid-cols-2">
          <label class="flex cursor-pointer items-center gap-3 rounded-[2px] border border-border bg-surface-2 px-3 py-2.5">
            <input
              type="checkbox"
              class="sr-only"
              :checked="profile.hide_posts"
              :disabled="privacySaving"
              @change="onPrivacyChange('hide_posts', ($event.target as HTMLInputElement).checked)"
            />
            <span
              class="relative h-6 w-11 shrink-0 rounded-full transition"
              :class="profile.hide_posts ? 'bg-primary' : 'bg-border'"
            >
              <span
                class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white transition"
                :class="profile.hide_posts ? 'translate-x-5' : ''"
              />
            </span>
            <span class="min-w-0 flex-1">
              <span class="block text-sm text-text">隐藏执行记录</span>
              <span class="block text-[11px] text-text-muted">
                {{ profile.hide_posts ? '已隐藏，其他宿主无法查阅' : '当前公开' }}
              </span>
            </span>
          </label>

          <label class="flex cursor-pointer items-center gap-3 rounded-[2px] border border-border bg-surface-2 px-3 py-2.5">
            <input
              type="checkbox"
              class="sr-only"
              :checked="profile.hide_likes"
              :disabled="privacySaving"
              @change="onPrivacyChange('hide_likes', ($event.target as HTMLInputElement).checked)"
            />
            <span
              class="relative h-6 w-11 shrink-0 rounded-full transition"
              :class="profile.hide_likes ? 'bg-primary' : 'bg-border'"
            >
              <span
                class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white transition"
                :class="profile.hide_likes ? 'translate-x-5' : ''"
              />
            </span>
            <span class="min-w-0 flex-1">
              <span class="block text-sm text-text">隐藏赞许记录</span>
              <span class="block text-[11px] text-text-muted">
                {{ profile.hide_likes ? '已隐藏，其他宿主无法查阅' : '当前公开' }}
              </span>
            </span>
          </label>
        </div>

        <p v-if="privacyError" class="mt-2 font-mono text-[11px] text-primary">
          // ERROR: {{ privacyError }}
        </p>
      </section>

      <!-- Tab 切换 -->
      <div class="cute-card hud-corners flex items-center gap-1 p-1.5">
        <button
          type="button"
          class="flex-1 rounded-[2px] px-3 py-2 font-mono text-xs tracking-wide transition"
          :class="activeTab === 'posts' ? 'bg-primary-soft text-primary' : 'text-text-muted hover:bg-surface-2 hover:text-text'"
          @click="switchTab('posts')"
        >
          {{ postsTabLabel }}
          <span class="ml-1 text-[11px]">{{ tabs.posts.loaded && !tabs.posts.hidden ? tabs.posts.count : '' }}</span>
        </button>
        <button
          type="button"
          class="flex-1 rounded-[2px] px-3 py-2 font-mono text-xs tracking-wide transition"
          :class="activeTab === 'likes' ? 'bg-primary-soft text-primary' : 'text-text-muted hover:bg-surface-2 hover:text-text'"
          @click="switchTab('likes')"
        >
          {{ likesTabLabel }}
          <span class="ml-1 text-[11px]">{{ tabs.likes.loaded && !tabs.likes.hidden ? tabs.likes.count : '' }}</span>
        </button>
      </div>

      <!-- 列表内容 -->
      <template v-if="tabs[activeTab].hidden">
        <div class="cute-card hud-corners flex flex-col items-center gap-2 px-6 py-14 text-center">
          <div class="font-mono text-2xl tracking-[0.2em] text-primary">[ ACCESS DENIED ]</div>
          <p class="text-base font-semibold text-text">该数据节点已被宿主设为私有</p>
          <p class="font-mono text-xs text-text-muted">因果线记录暂不可查阅</p>
        </div>
      </template>

      <template v-else-if="tabs[activeTab].loading && !tabs[activeTab].items.length">
        <div class="space-y-4">
          <div v-for="n in 2" :key="n" class="cute-card h-32 animate-pulse" />
        </div>
      </template>

      <template v-else-if="tabs[activeTab].error">
        <div class="cute-card flex flex-col items-center gap-3 px-6 py-12 text-center">
          <div class="font-mono text-2xl tracking-[0.2em] text-primary">[ ! ]</div>
          <p class="font-mono text-xs text-text-muted">{{ tabs[activeTab].error }}</p>
          <button type="button" class="cute-btn bg-primary text-white" @click="loadTab(activeTab, true)">
            重新加载
          </button>
        </div>
      </template>

      <template v-else-if="!tabs[activeTab].items.length">
        <div class="cute-card flex flex-col items-center gap-2 px-6 py-14 text-center">
          <div class="font-mono text-xl tracking-[0.2em] text-text-muted">[ NULL ]</div>
          <p class="text-base font-semibold text-text">{{ emptyText }}</p>
          <p class="text-sm text-text-muted">
            {{ isSelf ? '当前节点没有可展示的因果线记录。' : '该节点暂无公开记录。' }}
          </p>
          <button
            v-if="isSelf"
            type="button"
            class="cute-btn mt-1 bg-primary text-white"
            @click="router.push({ name: 'home' })"
          >
            [ 返回任务大厅 ]
          </button>
        </div>
      </template>

      <template v-else>
        <div class="space-y-4">
          <PostCard v-for="item in tabs[activeTab].items" :key="item.id" :post="item" />
        </div>

        <div
          v-if="tabs[activeTab].items.length < tabs[activeTab].count"
          class="flex justify-center"
        >
          <button
            type="button"
            class="cute-btn border border-border bg-surface text-text hover:shadow-card disabled:opacity-60"
            :disabled="tabs[activeTab].loading"
            @click="loadTab(activeTab)"
          >
            {{ tabs[activeTab].loading ? '加载中…' : '加载更多' }}
          </button>
        </div>
      </template>
    </template>
  </div>
</template>
