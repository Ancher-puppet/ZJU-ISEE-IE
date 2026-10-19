import { useState, useEffect } from 'react';
import GeneratePanel from './components/GeneratePanel';
import ResultPanel from './components/ResultPanel';
import ReasonPanel from './components/ReasonPanel';
import HistoryPanel from './components/HistoryPanel';
import { recognizeCaptcha, base64ToFile } from './api/mock';
import './App.css';

function loadHistory() {
  try {
    const raw = localStorage.getItem('captcha_history');
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export default function App() {
  const [started, setStarted] = useState(false);
  const [fading, setFading] = useState(false);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [reasoning, setReasoning] = useState([]);
  const [mode, setMode] = useState('recognize');
  const [history, setHistory] = useState(loadHistory);
  const [historySelected, setHistorySelected] = useState(null);
  const [generatedImage, setGeneratedImage] = useState(null);

  useEffect(() => {
    localStorage.setItem('captcha_history', JSON.stringify(history));
  }, [history]);

  function handleStart() {
    setFading(true);
    setTimeout(() => setStarted(true), 800);
  }

  async function handleRecognize(file) {
    setLoading(true);
    setResult(null);
    setReasoning([]);
    setHistorySelected(null);
    try {
      const data = await recognizeCaptcha(file);
      setResult(data);
      setReasoning(data.reasoning);
      const reader = new FileReader();
      reader.onload = (ev) => {
        setHistory((prev) => {
          const next = [{ preview: ev.target.result, data }, ...prev];
          return next.slice(0, 6);
        });
      };
      reader.readAsDataURL(file);
    } catch (err) {
      alert('识别失败: ' + err.message);
    } finally {
      setLoading(false);
    }
  }

  function handleRecognizeGenerated(base64Image) {
    const file = base64ToFile(base64Image);
    handleRecognize(file);
  }

  function handleSelectHistory(item) {
    setHistorySelected(item);
    setResult(item.data);
    setReasoning(item.data.reasoning);
  }

  function handleDeleteHistory(idx) {
    setHistory((prev) => prev.filter((_, i) => i !== idx));
    if (historySelected && history[idx] === historySelected) {
      setHistorySelected(null);
    }
  }

  function handleClearHistory() {
    setHistory([]);
    setHistorySelected(null);
  }

  if (!started) {
    return (
      <div className={`landing ${fading ? 'fade-out' : ''}`}>
        <img src="/bg.jpg" alt="" className="landing-bg" />
        <div className="landing-title-wrap">
          <h1 className="landing-title glow-text">CAPTCHA</h1>
          <h1 className="landing-title glow-text">RECOGNITION</h1>
        </div>
        <button className="btn-start" onClick={handleStart}>START</button>
      </div>
    );
  }

  return (
    <div className="app fade-in">
      <div className="app-bg" />

      <nav className="sidebar">
        <button
          className={`sidebar-btn ${mode === 'recognize' ? 'active' : ''}`}
          onClick={() => { setMode('recognize'); setHistorySelected(null); }}
          title="识别"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
        </button>
        <button
          className={`sidebar-btn ${mode === 'history' ? 'active' : ''}`}
          onClick={() => { setMode('history'); setHistorySelected(null); }}
          title="历史"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" />
            <polyline points="12 6 12 12 16 14" />
          </svg>
        </button>
      </nav>

      <div className="main-wrap">
        <header className="app-header">
          <h1>验证码识别调度系统</h1>
        </header>

        {mode === 'recognize' ? (
          <main className={`app-main ${!result ? 'centered' : ''}`}>
            {!result && (
              <p className="upload-hint">在线生成验证码，AI 自动识别类型并返回结果</p>
            )}

            <div className="main-top">
              <GeneratePanel
                onRecognize={handleRecognizeGenerated}
                loading={loading}
                hasResult={!!result}
                generatedImage={generatedImage}
                setGeneratedImage={setGeneratedImage}
              />
              <ResultPanel data={result} />
            </div>
            <ReasonPanel reasoning={reasoning} />
          </main>
        ) : historySelected ? (
          <main className="app-main">
            <button className="btn-back" onClick={() => setHistorySelected(null)}>返回列表</button>
            <div className="main-top">
              <div className="history-detail-img">
                <img src={historySelected.preview} alt="" />
              </div>
              <ResultPanel data={historySelected.data} />
            </div>
            <ReasonPanel reasoning={historySelected.data.reasoning} />
          </main>
        ) : (
          <main className="app-main">
            <HistoryPanel
              history={history}
              onSelect={handleSelectHistory}
              onDelete={handleDeleteHistory}
              onClear={handleClearHistory}
            />
          </main>
        )}
      </div>
    </div>
  );
}
