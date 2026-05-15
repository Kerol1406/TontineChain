const express = require('express');
const { db, admin } = require('../services/firebase');
const { getUserProfile, updateUserProfile, getUserTontines, getUserGlobalScore, getUserStats } = require('../services/userService');
const { createCustodialWallet } = require('../services/walletService');

const router = express.Router();

/**
 * GET /api/users/:wallet/profile
 * Retrieve user profile information
 */
router.get('/users/:wallet/profile', async (req, res) => {
  try {
    const { wallet } = req.params;
    // Normalize wallet to lowercase for consistency
    const normalizedWallet = String(wallet || '').toLowerCase();
    
    const profile = await getUserProfile(normalizedWallet);

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

    // Normalize wallet to lowercase for consistency
    const normalizedWallet = String(wallet || '').toLowerCase();
    
    const profileData = {
      pseudo,
      email,
      phone,
      bio,
      avatar
    };

    const updatedProfile = await updateUserProfile(normalizedWallet, profileData);

    return res.status(200).json({ ok: true, profile: updatedProfile });
  } catch (error) {
    console.error('[userRoutes] update profile error:', error);
    return res.status(500).json({ ok: false, error: error.message });
  }
});

/**
 * PUT /api/users/:userId/profile
 * Create or update user profile (Firebase UID version)
 * Body: { pseudo, email, phone, bio, avatar }
 */
router.put('/users/:userId/profile', async (req, res) => {
  try {
    const { userId } = req.params;
    const { pseudo, email, phone, bio, avatar } = req.body;

    // Normalize userId to lowercase to match backend wallet normalization
    const normalizedUserId = String(userId || '').toLowerCase();

    const now = admin.firestore.FieldValue.serverTimestamp();

    const updateData = {
      pseudo: pseudo?.trim() || '',
      email: email?.trim() || '',
      phone: phone?.trim() || '',
      bio: bio?.trim() || '',
      avatar: avatar || null,
      updatedAt: now
    };

    // Check if user doc exists
    const userRef = db.collection('users').doc(normalizedUserId);
    const existingSnap = await userRef.get();

    if (!existingSnap.exists) {
      // First creation: add createdAt and create custodial wallet
      updateData.createdAt = now;
      updateData.verified = false;
      updateData.firebaseUid = userId;
      
      const custodialWallet = createCustodialWallet();
      updateData.walletAddress = custodialWallet.walletAddress;
      updateData.walletType = 'custodial';
      updateData.walletEncryptedPrivateKey = custodialWallet.walletEncryptedPrivateKey;
      updateData.walletEncryptedIv = custodialWallet.walletEncryptedIv;
      updateData.walletEncryptedAuthTag = custodialWallet.walletEncryptedAuthTag;
      updateData.walletCreatedAt = now;
    } else if (!existingSnap.data()?.walletAddress) {
      // Existing user but no wallet: create one
      const custodialWallet = createCustodialWallet();
      updateData.walletAddress = custodialWallet.walletAddress;
      updateData.walletType = 'custodial';
      updateData.walletEncryptedPrivateKey = custodialWallet.walletEncryptedPrivateKey;
      updateData.walletEncryptedIv = custodialWallet.walletEncryptedIv;
      updateData.walletEncryptedAuthTag = custodialWallet.walletEncryptedAuthTag;
      updateData.walletCreatedAt = now;
    }

    await userRef.set(updateData, { merge: true });

    const updatedDoc = await userRef.get();
    const profile = updatedDoc.data();

    return res.status(200).json({ ok: true, profile });
  } catch (error) {
    console.error('[userRoutes] PUT update profile error:', error);
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
