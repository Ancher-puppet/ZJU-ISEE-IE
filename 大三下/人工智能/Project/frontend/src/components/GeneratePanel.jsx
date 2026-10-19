import { useState, useRef } from 'react';
import { generateTextCaptcha, generateClickCaptcha } from '../api/mock';

export default function GeneratePanel({
  onRecognize,
  loading,
  hasResult,
  generatedImage,
  setGeneratedImage,
}) {
  const [captchaType, setCaptchaType] = useState('text');
  const [textInput, setTextInput] = useState('');
  const [clickInputs, setClickInputs] = useState(['', '', '', '']);
  const [generating, setGenerating] = useState(false);
  const [error, setError] = useState('');
  const [difficulty, setDifficulty] = useState('easy'); // 'easy' | 'normal'
  const [useBackground, setUseBackground] = useState(true);

  // IME 组合输入状态追踪 — 每个输入框独立标记
  const composingRef = useRef(Array(6).fill(false));

  const clickCount = clickInputs.length;

  function handleClickCountChange(delta) {
    const next = clickCount + delta;
    if (next < 2 || next > 6) return;
    if (delta > 0) {
      setClickInputs([...clickInputs, '']);
    } else {
      setClickInputs(clickInputs.slice(0, -1));
    }
  }

  function handleClickInputChange(index, value) {
    // IME 组合输入期间不截断，让输入法完成组合
    if (composingRef.current[index]) {
      const next = [...clickInputs];
      next[index] = value;
      setClickInputs(next);
      return;
    }
    // 组合结束后只取最后一个字符
    const next = [...clickInputs];
    next[index] = value.slice(-1);
    setClickInputs(next);
  }

  function handleCompositionStart(index) {
    composingRef.current[index] = true;
  }

  function handleCompositionEnd(index, e) {
    composingRef.current[index] = false;
    // 组合结束后取最后一个字符
    const next = [...clickInputs];
    next[index] = e.target.value.slice(-1);
    setClickInputs(next);
  }

  function isValidText() {
    return /^[0-9A-Za-z]{4}$/.test(textInput);
  }

  function isValidClick() {
    return clickInputs.every((c) => c.trim().length === 1);
  }

  async function handleGenerate() {
    setError('');
    setGenerating(true);
    try {
      let result;
      if (captchaType === 'text') {
        result = await generateTextCaptcha(textInput);
      } else {
        result = await generateClickCaptcha(clickInputs.filter((c) => c.trim()), difficulty, useBackground);
      }
      setGeneratedImage(result.image);
    } catch (e) {
      setError(e.message || '生成失败，请检查后端是否启动');
    } finally {
      setGenerating(false);
    }
  }

  function handleTypeSwitch(type) {
    setCaptchaType(type);
    setGeneratedImage(null);
    setError('');
  }

  function handleRecognize() {
    if (!generatedImage) return;
    onRecognize(generatedImage);
  }

  const canGenerate =
    captchaType === 'text' ? isValidText() : isValidClick();
  const canRecognize = !!generatedImage && !loading;

  return (
    <div className={`upload-panel ${hasResult ? 'shifted' : ''}`}>
      {/* 类型选择器 */}
      <div className="generate-type-selector">
        <button
          className={`type-btn ${captchaType === 'text' ? 'active' : ''}`}
          onClick={() => handleTypeSwitch('text')}
        >
          文字验证码
        </button>
        <button
          className={`type-btn ${captchaType === 'click' ? 'active' : ''}`}
          onClick={() => handleTypeSwitch('click')}
        >
          文字点选验证码
        </button>
      </div>

      {/* 输入区域 */}
      <div className="generate-input-area">
        {captchaType === 'text' ? (
          <input
            className="generate-text-input"
            type="text"
            maxLength={4}
            placeholder="输入4位字符（如 A3bK）"
            value={textInput}
            onChange={(e) => setTextInput(e.target.value.replace(/[^0-9A-Za-z]/g, ''))}
          />
        ) : (
          <div className="click-inputs-row">
            {clickInputs.map((val, i) => (
              <input
                key={i}
                className="click-char-input"
                type="text"
                placeholder={`字${i + 1}`}
                value={val}
                onChange={(e) => handleClickInputChange(i, e.target.value)}
                onCompositionStart={() => handleCompositionStart(i)}
                onCompositionEnd={(e) => handleCompositionEnd(i, e)}
              />
            ))}
            {clickCount > 2 && (
              <button
                className="count-btn"
                onClick={() => handleClickCountChange(-1)}
                title="减少一个"
              >
                −
              </button>
            )}
            {clickCount < 6 && (
              <button
                className="count-btn"
                onClick={() => handleClickCountChange(1)}
                title="增加一个"
              >
                +
              </button>
            )}
          </div>
        )}
      </div>

      {/* 选项 — 仅点选验证码显示 */}
      {captchaType === 'click' && (
        <>
          <div className="difficulty-toggle">
            <span className="difficulty-label">难度</span>
            <button
              className={`diff-btn ${difficulty === 'easy' ? 'active' : ''}`}
              onClick={() => setDifficulty('easy')}
            >
              简单
            </button>
            <button
              className={`diff-btn ${difficulty === 'normal' ? 'active' : ''}`}
              onClick={() => setDifficulty('normal')}
            >
              正常
            </button>
          </div>
          <div className="difficulty-toggle">
            <span className="difficulty-label">背景</span>
            <button
              className={`diff-btn ${useBackground ? 'active' : ''}`}
              onClick={() => setUseBackground(true)}
            >
              图片
            </button>
            <button
              className={`diff-btn ${!useBackground ? 'active' : ''}`}
              onClick={() => setUseBackground(false)}
            >
              纯色
            </button>
          </div>
        </>
      )}

      {/* 生成按钮 */}
      <button
        className="btn-generate"
        onClick={handleGenerate}
        disabled={!canGenerate || generating}
      >
        {generating ? '生成中...' : '生成验证码'}
      </button>

      {error && <p className="generate-error">{error}</p>}

      {/* 图片预览 */}
      <div className="generate-preview">
        {generatedImage ? (
          <img
            src={`data:image/png;base64,${generatedImage}`}
            alt="生成的验证码"
            className="preview-img"
          />
        ) : (
          <div className="upload-placeholder">
            <div className="upload-icon">◇</div>
            <p>点击"生成验证码"查看</p>
          </div>
        )}
      </div>

      {/* 开始识别按钮 */}
      <button
        className="btn-recognize"
        onClick={handleRecognize}
        disabled={!canRecognize}
      >
        {loading ? (
          <span className="loading-dots">
            识别中<span className="dots">...</span>
          </span>
        ) : (
          '开始识别'
        )}
      </button>
    </div>
  );
}
