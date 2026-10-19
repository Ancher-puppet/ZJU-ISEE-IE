export default function ResultPanel({ data }) {
  if (!data) return null;

  return (
    <div className="result-panel slide-in">
      <div className="result-type">
        {data.type === 'text' ? '文字验证码' : '文字点选验证码'}
      </div>
      <div className="result-value">{data.result}</div>
      <div className="result-bar">
        <div className="result-bar-label">置信度</div>
        <div className="result-bar-track">
          <div
            className="result-bar-fill"
            style={{ width: `${data.confidence * 100}%` }}
          />
        </div>
        <div className="result-bar-num">{(data.confidence * 100).toFixed(1)}%</div>
      </div>
      {data.visualization && (
        <div className="result-visualization">
          <div className="result-bar-label">YOLO 检测结果</div>
          <img
            src={`data:image/png;base64,${data.visualization}`}
            alt="YOLO detection"
            style={{ maxWidth: '100%', borderRadius: '8px', marginTop: '8px' }}
          />
        </div>
      )}
    </div>
  );
}
