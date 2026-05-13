const express = require('express');
const { getUserProfile, updateUserProfile, getUserTontines, getUserGlobalScore, getUserStats } = require('../services/userService');

const router = express.Router();

/**
 * GET /api/users/:wallet/profile
 * Retrieve user profile information
 */
router.get('/users/:wallet/profile', async (req, res) => {
  try {
    const { wallet } = req.params;
    const profile = await getUserProfile(wallet);

    if (!profile) {
      return res.status(404).json({ ok: false, error: 'User profile not found' });
    }

    return res.status(200).json({ ok: true, profile });
  } catch (error) {
    console.error('[userRoutes] get profile error:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

/**
 * POST /api/users/:wallet/profile
 * Create or update user profile
 * Body: { pseudo, email, phone, bio, avatar }
 */
router.post('/users/:wallet/profile', async (req, res) => {
  try {
    const { wallet } = req.params;
    const { pseudo, email, phone, bio, avatar } = req.body;

    const profileData = {
      pseudo,
      email,
      phone,
      bio,
      avatar
    };

    const updatedProfile = await updateUserProfile(wallet, profileData);

    return res.status(200).json({ ok: true, profile: updatedProfile });
  } catch (error) {
    console.error('[userRoutes] update profile error:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

/**
 * GET /api/users/:wallet/tontines
 * List all tontines where user is a member
 */
router.get('/users/:wallet/tontines', async (req, res) => {
  try {
    const { wallet } = req.params;
    const tontines = await getUserTontines(wallet);

    return res.status(200).json({ ok: true, tontines });
  } catch (error) {
    console.error('[userRoutes] get tontines error:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

/**
 * GET /api/users/:wallet/scores
 * Get user's global score
 */
router.get('/users/:wallet/scores', async (req, res) => {
  try {
    const { wallet } = req.params;
    const globalScore = await getUserGlobalScore(wallet);

    return res.status(200).json({ ok: true, globalScore });
  } catch (error) {
    console.error('[userRoutes] get scores error:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

// Compatibility alias for older client code
router.get('/users/:wallet/score', async (req, res) => {
  try {
    const { wallet } = req.params;
    const globalScore = await getUserGlobalScore(wallet);

    return res.status(200).json({ ok: true, globalScore });
  } catch (error) {
    console.error('[userRoutes] get score error:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

/**
 * GET /api/users/:wallet/stats
 * Get comprehensive user statistics
 */
router.get('/users/:wallet/stats', async (req, res) => {
  try {
    const { wallet } = req.params;
    const stats = await getUserStats(wallet);

    return res.status(200).json({ ok: true, stats });
  } catch (error) {
    console.error('[userRoutes] get stats error:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

/**
 * GET /api/users/:wallet/next-due
 * Returns the next due tontine info for the user
 */
router.get('/users/:wallet/next-due', async (req, res) => {
  try {
    const { wallet } = req.params;
    // lazy require to avoid cycles
    const { getUserNextDue } = require('../services/userService');

    const next = await getUserNextDue(wallet);
    if (!next) return res.status(200).json({ ok: true, next: null });
    return res.status(200).json({ ok: true, next });
  } catch (error) {
    console.error('[userRoutes] get next-due error:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

module.exports = router;
