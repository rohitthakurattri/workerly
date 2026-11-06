// Phase 4's push-only worker, kept so browsers that registered it update to the full worker.
importScripts(`/sw.js${self.location.search}`)
