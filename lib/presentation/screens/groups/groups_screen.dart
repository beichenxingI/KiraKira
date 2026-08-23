import 'dart:io';
import 'package:kirakira/presentation/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kirakira/data/models/group.dart';
import 'package:kirakira/data/models/character.dart';
import 'package:kirakira/data/repositories/character_repository.dart';
import 'package:kirakira/presentation/providers/group_providers.dart';
import 'package:kirakira/presentation/providers/character_providers.dart';
import 'package:kirakira/presentation/theme/app_theme.dart';
import 'package:kirakira/presentation/widgets/common/character_avatar_image.dart';
import 'package:kirakira/l10n/generated/app_localizations.dart';

/// Groups list screen
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.groupChats),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(groupListProvider.notifier).refresh(),
          ),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? DesignTokens.darkCard
                          : DesignTokens.lightSurface,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusFull),
                    ),
                    child: const Icon(
                      Icons.groups,
                      size: 40,
                      color: DesignTokens.darkTextTertiary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  Text(
                    AppLocalizations.of(context)!.noGroupChatsYet,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: DesignTokens.fontSizeBodyLarge,
                          fontWeight: DesignTokens.weightMedium,
                        ),
                  ),
                  const SizedBox(height: DesignTokens.spaceSm),
                  Text(
                    AppLocalizations.of(context)!.createGroupDescription,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeXs,
                      color: DesignTokens.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceLg),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateGroupDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(AppLocalizations.of(context)!.createGroup),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: DesignTokens.paddingCard,
            itemCount: groups.length,
            itemBuilder: (context, index) {
              return _StaggeredEntrance(
                index: index,
                child: _GroupCard(group: groups[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('${AppLocalizations.of(context)!.error}: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(groupListProvider.notifier).refresh(),
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.newGroup),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _CreateGroupDialog(),
    );
  }
}

/// 列表项进场:错峰 50ms 淡入上移(宪法 §五,与角色列表同款)
class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _StaggeredEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    const duration = DesignTokens.durationMd;
    final delay = index.clamp(0, 12) * 50;
    final total = duration + delay;
    final intervalBegin = delay / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(intervalBegin, 1, curve: DesignTokens.curveDecelerate),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// 加载骨架:实底 + 400ms 呼吸(0.5↔1.0)
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: DesignTokens.paddingCard,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (_, __) => _BreathingRow(isDark: isDark),
    );
  }
}

class _BreathingRow extends StatefulWidget {
  final bool isDark;
  const _BreathingRow({required this.isDark});

  @override
  State<_BreathingRow> createState() => _BreathingRowState();
}

class _BreathingRowState extends State<_BreathingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: DesignTokens.durationLg),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: DesignTokens.curveEmphasized),
      ),
      child: Container(
        height: 88,
        margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
        decoration: BoxDecoration(
          color: widget.isDark ? DesignTokens.darkCard : DesignTokens.lightSeparator,
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        ),
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final Group group;

  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      ),
      child: InkWell(
        onTap: () => context.push('/groups/${group.id}'),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        child: Padding(
          padding: DesignTokens.paddingCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Group avatar or first few members
                  _buildGroupAvatar(context, ref),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (group.description != null && group.description!.isNotEmpty)
                          Text(
                            group.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.membersAndMode(group.members.length, (group.settings.responseMode ?? GroupResponseMode.natural).name),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'chat',
                        onTap: () => _startGroupChat(context, ref),
                        child: ListTile(
                          leading: const Icon(Icons.chat),
                          title: Text(AppLocalizations.of(context)!.startChat),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        onTap: () => context.push('/groups/${group.id}/edit'),
                        child: ListTile(
                          leading: const Icon(Icons.edit),
                          title: Text(AppLocalizations.of(context)!.edit),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        onTap: () => _confirmDelete(context, ref),
                        child: ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: Text(AppLocalizations.of(context)!.delete, style: const TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Member avatars
              _buildMemberAvatars(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(BuildContext context, WidgetRef ref) {
    return Container(
      width: 56,
      height: 56,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
        ),
      child: Center(
        child: Icon(
          Icons.groups,
          size: 28,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildMemberAvatars(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: group.members.length,
        itemBuilder: (context, index) {
          final member = group.members[index];
          return FutureBuilder<Character?>(
            future: ref.read(characterRepositoryProvider).getCharacter(member.characterId),
            builder: (context, snapshot) {
              final Character? character = snapshot.data;
              return Padding(
                padding: const EdgeInsets.only(right: DesignTokens.spaceSm),
                child: Tooltip(
                  message: character?.name ?? 'Unknown',
                  child: Stack(
                    children: [
                      character?.assets?.avatarPath != null
                          ? CharacterAvatarCircle(
                              imagePath: character!.assets!.avatarPath!,
                              radius: 20,
                              errorBuilder: (_, __, ___) => CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.darkDivider,
                                child: Text(
                                  character.name.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontSize: DesignTokens.fontSizeBodyLarge),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.darkDivider,
                              child: Text(
                                character?.name.substring(0, 1).toUpperCase() ?? '?',
                                style: const TextStyle(fontSize: DesignTokens.fontSizeBodyLarge),
                              ),
                            ),
                      if (member.isMuted)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(DesignTokens.spaceXxs),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                            ),
                            child: const Icon(
                              Icons.volume_off,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _startGroupChat(BuildContext context, WidgetRef ref) {
    // TODO: Create group chat and navigate to it
    // TRACKED: recorded in DiaoYan/18 (phase-6 tech-debt)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.groupChatWillBeImplemented)),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteGroup),
        content: Text(AppLocalizations.of(context)!.deleteGroupConfirmation(group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(groupListProvider.notifier).deleteGroup(group.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.groupDeleted(group.name))),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }
}

class _CreateGroupDialog extends ConsumerStatefulWidget {
  const _CreateGroupDialog();

  @override
  ConsumerState<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<_CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _selectedCharacterIds = <String>{};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charactersAsync = ref.watch(characterListProvider);

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.createGroup),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.groupNameRequired,
                hintText: AppLocalizations.of(context)!.enterGroupName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.description,
                hintText: AppLocalizations.of(context)!.optionalDescription,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.selectCharacters,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: charactersAsync.when(
                data: (characters) {
                  if (characters.isEmpty) {
                    return Center(
                      child: Text(AppLocalizations.of(context)!.noCharactersAvailable),
                    );
                  }
                  return ListView.builder(
                    itemCount: characters.length,
                    itemBuilder: (context, index) {
                      final character = characters[index];
                      final isSelected = _selectedCharacterIds.contains(character.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedCharacterIds.add(character.id);
                            } else {
                              _selectedCharacterIds.remove(character.id);
                            }
                          });
                        },
                        title: Text(character.name),
                        secondary: character.assets?.avatarPath != null
                            ? CharacterAvatarCircle(
                                imagePath: character.assets!.avatarPath!,
                                errorBuilder: (_, __, ___) => CircleAvatar(
                                  child: Text(character.name.substring(0, 1).toUpperCase()),
                                ),
                              )
                            : CircleAvatar(
                                child: Text(character.name.substring(0, 1).toUpperCase()),
                              ),
                      );
                    },
                  );
                },
        loading: () => const _SkeletonList(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            if (_selectedCharacterIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: DesignTokens.spaceSm),
                child: Text(
                  AppLocalizations.of(context)!.charactersSelected(_selectedCharacterIds.length),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentColor,
                      ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        ElevatedButton(
          onPressed: _isCreating || _nameController.text.isEmpty || _selectedCharacterIds.length < 2
              ? null
              : _createGroup,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)!.create),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    if (_nameController.text.isEmpty) return;
    if (_selectedCharacterIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.selectAtLeast2Characters)),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      await ref.read(groupListProvider.notifier).createGroup(
            name: _nameController.text,
            description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
            characterIds: _selectedCharacterIds.toList(),
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.groupCreatedSuccessfully)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToCreateGroup(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}