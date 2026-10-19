export default function HistoryPanel({ history, onSelect, onDelete, onClear }) {
  if (history.length === 0) {
    return (
      <div className="history-empty">
        <p>暂无识别记录</p>
      </div>
    );
  }

  return (
    <div className="history-panel">
      <div className="history-header">
        <h2>历史记录</h2>
        <button className="btn-clear" onClick={onClear}>清空全部</button>
      </div>
      <div className="history-grid">
        {history.map((item, idx) => (
          <div className="history-card" key={idx}>
            <div className="history-card-img" onClick={() => onSelect(item)}>
              <img src={item.preview} alt="" className="history-thumb" />
              <button
                className="btn-delete"
                onClick={(e) => { e.stopPropagation(); onDelete(idx); }}
                title="删除"
              >
                x
              </button>
            </div>
            <div className="history-info" onClick={() => onSelect(item)}>
              <span className="history-type">
                {item.data.type === 'text' ? '文字' : '图形'}
              </span>
              <span className="history-result">{item.data.result}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
