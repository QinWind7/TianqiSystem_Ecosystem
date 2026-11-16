import { defineStore } from 'pinia'
import { ref } from 'vue'

export interface ThemePreset {
  code: string
  name: string
  emoji: string
  isDark: boolean
}

/** 内置 2 套皮肤，code 与后端 themes_themes.code 对齐。 */
export const THEME_PRESETS: ThemePreset[] = [
  { code: 'sakura', name: '极简白', emoji: '⚪', isDark: false },
  { code: 'alert', name: '黑红警报 (Dark Alert)', emoji: '🚨', isDark: true },
]

export const DEFAULT_THEME = 'sakura'

export const useThemeStore = defineStore(
  'theme',
  () => {
    const code = ref<string>(DEFAULT_THEME)

    /** 只接受内置皮肤；旧版本残留的 ocean / midnight / matcha 会回落到默认皮肤。 */
    function setTheme(next: string): void {
      code.value = THEME_PRESETS.some((item) => item.code === next) ? next : DEFAULT_THEME
    }

    return { code, setTheme }
  },
  // key 固定为 'theme'，index.html 的内联防白闪脚本读的就是这条记录
  { persist: { key: 'theme' } },
)
