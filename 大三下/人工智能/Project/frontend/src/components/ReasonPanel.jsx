import { useState, useEffect } from 'react';

export default function ReasonPanel({ reasoning }) {
  const [visible, setVisible] = useState(0);

  useEffect(() => {
    if (!reasoning || reasoning.length === 0) {
      setVisible(0);
      return;
    }
    setVisible(0);
    let i = 0;
    const timer = setInterval(() => {
      i++;
      if (i >= reasoning.length) {
        clearInterval(timer);
      }
      setVisible(i);
    }, 600);
    return () => clearInterval(timer);
  }, [reasoning]);

  if (!reasoning || reasoning.length === 0) return null;

  return (
    <div className="reason-panel">
      <h2>AI Agent 推理过程</h2>
      <div className="reason-grid">
        {reasoning.map((item, idx) => (
          <div
            className={`reason-step ${idx < visible ? 'show' : ''}`}
            key={item.step}
          >
            <div className="step-num">{item.step}</div>
            <div className="step-body">
              <div className="step-action">{item.action}</div>
              <div className="step-detail">{item.detail}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
