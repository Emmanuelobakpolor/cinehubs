import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../app_colors.dart';
import '../../app_theme.dart';
import '../../services/user_service.dart';

class EditProfileScreen extends StatefulWidget {
  /// Pre-fill data. If null the screen fetches it.
  final UserProfile? profile;

  const EditProfileScreen({super.key, this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controllers always created immediately — pre-filled from widget.profile if available
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;

  UserProfile? _profile; // holds the authoritative profile (fetched or passed)
  bool _isFetching = false; // background fetch indicator
  String? _fetchError;

  bool _isSaving = false;
  String? _saveError;

  File? _pickedImage;
  bool _uploadingPicture = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill instantly from whatever was passed (may be null if opened from Settings)
    _nameController =
        TextEditingController(text: widget.profile?.fullName ?? '');
    _phoneController =
        TextEditingController(text: widget.profile?.phoneNumber ?? '');
    _bioController =
        TextEditingController(text: widget.profile?.bio ?? '');
    _profile = widget.profile;

    // Always refresh from server so data is current
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isFetching = true;
      _fetchError = null;
    });
    try {
      final fresh = await UserService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = fresh;
        // Only update controllers if the user hasn't started typing
        // (cursor position == 0 means untouched)
        if (_nameController.selection.baseOffset <= 0) {
          _nameController.text = fresh.fullName;
        }
        if (_phoneController.selection.baseOffset <= 0) {
          _phoneController.text = fresh.phoneNumber ?? '';
        }
        if (_bioController.selection.baseOffset <= 0) {
          _bioController.text = fresh.bio ?? '';
        }
      });
    } on UserException catch (e) {
      if (mounted) setState(() => _fetchError = e.message);
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() {
      _pickedImage = File(picked.path);
      _uploadingPicture = true;
    });

    try {
      final updated = await UserService.uploadProfilePicture(picked.path);
      if (mounted) {
        setState(() {
          _profile = updated;
          // Switch from local file to the server URL so we always show the persisted picture.
          _pickedImage = null;
        });
      }
    } on UserException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.errorRed),
        );
        // Revert the local preview on failure.
        setState(() => _pickedImage = null);
      }
    } finally {
      if (mounted) setState(() => _uploadingPicture = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'Full name cannot be empty.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final updated = await UserService.updateProfile(
        fullName: name,
        phoneNumber: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (!mounted) return;
      // Pop and return the updated profile so callers can update immediately.
      // If the server PATCH response omits profile_picture, carry over the URL
      // that was set when the user uploaded their picture earlier in this session.
      final toReturn = (updated.profilePictureUrl == null &&
              _profile?.profilePictureUrl != null)
          ? UserProfile(
              id: updated.id,
              fullName: updated.fullName,
              email: updated.email,
              phoneNumber: updated.phoneNumber,
              bio: updated.bio,
              profilePictureUrl: _profile!.profilePictureUrl,
              isEmailVerified: updated.isEmailVerified,
              watchedCount: updated.watchedCount,
              savedCount: updated.savedCount,
              reviewsCount: updated.reviewsCount,
            )
          : updated;
      Navigator.pop(context, toReturn);
    } on UserException catch (e) {
      setState(() => _saveError = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          // Subtle background-fetch indicator
          if (_isFetching)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // ── Avatar ──
            Center(
              child: GestureDetector(
                onTap: _uploadingPicture ? null : _pickAndUploadImage,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                        color: theme.iconBg,
                      ),
                      child: ClipOval(
                        child: _pickedImage != null
                            ? Image.file(_pickedImage!, fit: BoxFit.cover)
                            : (_profile?.profilePictureUrl != null &&
                                    _profile!.profilePictureUrl!.isNotEmpty)
                                ? Image.network(
                                    _profile!.profilePictureUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, e) => const Icon(
                                        Icons.person,
                                        size: 48,
                                        color: AppColors.textGrey),
                                  )
                                : const Icon(Icons.person,
                                    size: 48, color: AppColors.textGrey),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.background,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.primary, width: 1.5),
                      ),
                      child: _uploadingPicture
                          ? const Padding(
                              padding: EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 14, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Fetch error banner ──
            if (_fetchError != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppColors.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_fetchError!,
                          style: const TextStyle(
                              color: AppColors.errorRed, fontSize: 13)),
                    ),
                    GestureDetector(
                      onTap: _fetchProfile,
                      child: const Text('Retry',
                          style: TextStyle(
                            color: AppColors.errorRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          )),
                    ),
                  ],
                ),
              ),
            ],

            // ── Email (read-only) ──
            _fieldLabel('Email Address', theme),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: theme.inputBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _isFetching && _profile == null
                        ? Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: theme.iconBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          )
                        : Text(
                            _profile?.email ?? '',
                            style: TextStyle(
                                color: theme.textSecondary, fontSize: 14),
                          ),
                  ),
                  const Icon(Icons.lock_outline,
                      size: 16, color: AppColors.textGrey),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Email cannot be changed',
                style: TextStyle(color: theme.textSecondary, fontSize: 12)),

            const SizedBox(height: 20),

            // ── Full Name ──
            _fieldLabel('Full Name', theme),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              decoration: _inputDecoration('Enter your full name', theme),
            ),

            const SizedBox(height: 20),

            // ── Phone ──
            _fieldLabel('Phone Number', theme),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              decoration: _inputDecoration('e.g. +2348012345678', theme),
            ),

            const SizedBox(height: 20),

            // ── Bio ──
            _fieldLabel('Bio', theme),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 150,
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
              decoration:
                  _inputDecoration('Tell us a bit about yourself…', theme),
            ),

            // ── Save error ──
            if (_saveError != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.errorRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_saveError!,
                          style: const TextStyle(
                              color: AppColors.errorRed, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, AppTheme theme) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: theme.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, AppTheme theme) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.textSecondary, fontSize: 14),
      filled: true,
      fillColor: theme.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
