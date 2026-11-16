import type { Board, BoardBrief } from '@/api/types'

/**
 * 后端分区 → 「天启系统」分类的展示映射。
 * 只影响前端展示，不改动数据库中的 slug / 名称 / 配色。
 */
interface SystemBoardMeta {
  name: string
  icon: string
  color: string
}

const SYSTEM_BOARDS: Record<string, SystemBoardMeta> = {
  anime: { name: '主线推演', icon: '01', color: '#4F46E5' },
  figure: { name: '实体构造', icon: '02', color: '#4338CA' },
  cosplay: { name: '形态拟态', icon: '03', color: '#6366F1' },
  illustrator: { name: '因果律探讨', icon: '04', color: '#6D74E8' },
  resource: { name: '资源置换', icon: '05', color: '#475569' },
  chat: { name: '异常反馈', icon: '06', color: '#64748B' },
}

/** 未知分区保持后端原值，避免新增分区时展示成空白。 */
export function withSystemBoard<T extends Board | BoardBrief>(board: T): T {
  const meta = SYSTEM_BOARDS[board.slug]
  return meta ? { ...board, ...meta } : board
}

/** 帖子内嵌的 board 一并替换为系统分类。 */
export function withSystemPost<T extends { board: BoardBrief }>(post: T): T {
  return { ...post, board: withSystemBoard(post.board) }
}
