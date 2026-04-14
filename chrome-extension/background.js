const TARGET_DOMAIN = "youtube.com";

// 自分が更新したタブのループ防止
const updatingTabs = new Set();

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  // URL変更イベントだけ拾う
  if (!changeInfo.url) return;

  // 自分が更新したタブは無視
  if (updatingTabs.has(tabId)) return;

  let url;
  try {
    url = new URL(changeInfo.url);
  } catch {
    return;
  }

  // 対象ドメインのみ処理
  if (!url.hostname.includes(TARGET_DOMAIN)) return;

  // 既存タブ検索
  const tabs = await chrome.tabs.query({});
  const existing = tabs.find(t => {
    try {
      return (
        t.id !== tabId &&
        t.url &&
        new URL(t.url).hostname.includes(TARGET_DOMAIN)
      );
    } catch {
      return false;
    }
  });

  if (!existing) return;

  try {
    // ループ防止フラグ
    updatingTabs.add(existing.id);

    // 既存タブにURL適用 + フォーカス
    await chrome.tabs.update(existing.id, {
      active: true,
      url: changeInfo.url
    });

    // 新規タブを閉じる
    await chrome.tabs.remove(tabId);
  } catch (e) {
    // 無視（削除済みなど）
  } finally {
    updatingTabs.delete(existing.id);
  }
});