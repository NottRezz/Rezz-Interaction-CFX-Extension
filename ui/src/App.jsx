import { useCallback, useEffect, useRef, useState } from 'react'
import { nuiPost, useNuiMessage } from 'orbit_ui_kit'
import { TargetMarker } from './components/TargetMarker'

// Lua's scan thread sends 'show' on Alt-down, 'updateTargets' at 20Hz while held, and 'hide'
// on Alt-up. Callback endpoints (optionSelected, close) and their payload shapes are unchanged
// from the vanilla UI this replaces, so client/main.lua needed no changes.
export default function App() {
  const [visible, setVisible] = useState(false)
  const [fading, setFading] = useState(false)
  const [targets, setTargets] = useState([])
  const [expandedId, setExpandedId] = useState(null)
  const hideTimeout = useRef(null)

  useNuiMessage((msg) => {
    if (msg.action === 'show') {
      if (hideTimeout.current) {
        clearTimeout(hideTimeout.current)
        hideTimeout.current = null
      }
      setFading(false)
      setVisible(true)
    } else if (msg.action === 'updateTargets') {
      setTargets(msg.targets || [])
    } else if (msg.action === 'hide') {
      setExpandedId(null)
      setFading(true)
      hideTimeout.current = setTimeout(() => {
        setVisible(false)
        setTargets([])
        hideTimeout.current = null
      }, 200)
    }
  }, [])

  const toggleExpand = useCallback((id) => {
    setExpandedId((cur) => (cur === id ? null : id))
  }, [])

  const selectOption = useCallback((targetId, opt) => {
    nuiPost('optionSelected', {
      targetId,
      event: opt.event,
      serverEvent: opt.serverEvent,
      args: opt.args || [],
      data: opt.data || {},
      index: opt.index,
    })
  }, [])

  useEffect(() => {
    function onKey(e) {
      if (e.key !== 'Escape' || !visible) return
      if (expandedId) {
        setExpandedId(null)
        return
      }
      nuiPost('close')
    }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [visible, expandedId])

  if (!visible) return null

  return (
    <div
      className={`ri-overlay rk-reset${fading ? ' ri-overlay--fading' : ''}`}
      onClick={() => setExpandedId(null)}
    >
      {targets.map((t) => (
        <TargetMarker
          key={t.id}
          target={t}
          expanded={expandedId === t.id}
          onToggle={toggleExpand}
          onSelect={selectOption}
        />
      ))}
    </div>
  )
}
