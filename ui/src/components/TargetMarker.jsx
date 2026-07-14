export function TargetMarker({ target, expanded, onToggle, onSelect }) {
  const firstIcon = (target.options[0] && target.options[0].icon) || 'fas fa-hand-pointer'
  const scale = Math.max(0.6, Math.min(1.0, 1.0 - target.dist / 10))

  return (
    <div
      className={`ri-marker${expanded ? ' ri-marker--expanded' : ''}`}
      style={{ left: `${target.screenX * 100}%`, top: `${target.screenY * 100}%` }}
    >
      <div
        className="ri-dot"
        style={{ transform: `scale(${scale})` }}
        onClick={(e) => {
          e.stopPropagation()
          onToggle(target.id)
        }}
      >
        <i className={firstIcon} />
      </div>

      <div className="ri-options">
        {target.options.map((opt) => (
          <div
            key={opt.index}
            className="ri-option"
            onClick={(e) => {
              e.stopPropagation()
              onSelect(target.id, opt)
            }}
          >
            <div className="ri-option-icon">
              <i className={opt.icon || 'fas fa-hand-pointer'} />
            </div>
            <div className="ri-option-text">
              <span className="ri-option-label">{opt.label || 'Interact'}</span>
              {opt.description && <span className="ri-option-desc">{opt.description}</span>}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
