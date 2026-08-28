/// Development-only flags — never gated behind build mode, just plain
/// constants flipped by hand before a release.
library;

/// When true, every node on the Ders Yolları path screen is shown as
/// tappable/unlocked regardless of the previous node's completion state,
/// so content can be reviewed and QA'd without grinding through the
/// whole path in order. Progress data (completion flags, the per-node
/// ring) is untouched — this only lifts the visual/interaction lock.
///
/// TODO: içerik tamamlanınca false yap.
const kDevUnlockAllNodes = true;
