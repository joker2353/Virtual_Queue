import 'package:flutter/material.dart';

enum NoticeType { info, warning, success, error, announcement }

class ElegantNoticeWidget extends StatelessWidget {
  final String? title;
  final String content;
  final NoticeType type;
  final bool showIcon;
  final VoidCallback? onTap;
  final Widget? actionButton;
  final bool isElevated;

  const ElegantNoticeWidget({
    super.key,
    this.title,
    required this.content,
    this.type = NoticeType.info,
    this.showIcon = true,
    this.onTap,
    this.actionButton,
    this.isElevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getNoticeConfig(type);

    Widget noticeContent = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: config.gradientColors,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: config.borderColor, width: 1.5),
        boxShadow:
            isElevated
                ? [
                  BoxShadow(
                    color: config.shadowColor.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Stack(
        children: [
          // Background decorative elements
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: config.decorativeColor1,
              ),
            ),
          ),
          Positioned(
            bottom: -15,
            left: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: config.decorativeColor2,
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null || showIcon) ...[
                  Row(
                    children: [
                      if (showIcon) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: config.iconGradientColors,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: config.iconColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            config.icon,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      if (title != null) ...[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: config.titleColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                height: 2.5,
                                width: 45,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: config.iconGradientColors,
                                  ),
                                  borderRadius: BorderRadius.circular(1.25),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Content container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: config.contentBorderColor,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (content.isNotEmpty) ...[
                        Text(
                          content,
                          style: TextStyle(
                            color: config.contentColor,
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.grey.shade500,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'No content available',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (actionButton != null) ...[
                        const SizedBox(height: 16),
                        actionButton!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: noticeContent);
    }

    return noticeContent;
  }

  _NoticeConfig _getNoticeConfig(NoticeType type) {
    switch (type) {
      case NoticeType.info:
        return _NoticeConfig(
          gradientColors: [Colors.blue.shade50, Colors.indigo.shade50],
          borderColor: Colors.blue.shade200,
          shadowColor: Colors.blue,
          decorativeColor1: Colors.blue.shade100.withOpacity(0.3),
          decorativeColor2: Colors.indigo.shade100.withOpacity(0.4),
          icon: Icons.info_rounded,
          iconColor: Colors.blue.shade600,
          iconGradientColors: [Colors.blue.shade600, Colors.indigo.shade500],
          titleColor: Colors.blue.shade800,
          contentColor: Colors.blue.shade900,
          contentBorderColor: Colors.blue.shade100,
        );

      case NoticeType.warning:
        return _NoticeConfig(
          gradientColors: [Colors.orange.shade50, Colors.amber.shade50],
          borderColor: Colors.orange.shade200,
          shadowColor: Colors.orange,
          decorativeColor1: Colors.orange.shade100.withOpacity(0.4),
          decorativeColor2: Colors.amber.shade100.withOpacity(0.3),
          icon: Icons.warning_rounded,
          iconColor: Colors.orange.shade600,
          iconGradientColors: [Colors.orange.shade500, Colors.amber.shade600],
          titleColor: Colors.orange.shade800,
          contentColor: Colors.orange.shade900,
          contentBorderColor: Colors.orange.shade100,
        );

      case NoticeType.success:
        return _NoticeConfig(
          gradientColors: [Colors.green.shade50, Colors.teal.shade50],
          borderColor: Colors.green.shade200,
          shadowColor: Colors.green,
          decorativeColor1: Colors.green.shade100.withOpacity(0.3),
          decorativeColor2: Colors.teal.shade100.withOpacity(0.4),
          icon: Icons.check_circle_rounded,
          iconColor: Colors.green.shade600,
          iconGradientColors: [Colors.green.shade600, Colors.teal.shade500],
          titleColor: Colors.green.shade800,
          contentColor: Colors.green.shade900,
          contentBorderColor: Colors.green.shade100,
        );

      case NoticeType.error:
        return _NoticeConfig(
          gradientColors: [Colors.red.shade50, Colors.pink.shade50],
          borderColor: Colors.red.shade200,
          shadowColor: Colors.red,
          decorativeColor1: Colors.red.shade100.withOpacity(0.3),
          decorativeColor2: Colors.pink.shade100.withOpacity(0.4),
          icon: Icons.error_rounded,
          iconColor: Colors.red.shade600,
          iconGradientColors: [Colors.red.shade600, Colors.pink.shade500],
          titleColor: Colors.red.shade800,
          contentColor: Colors.red.shade900,
          contentBorderColor: Colors.red.shade100,
        );

      case NoticeType.announcement:
        return _NoticeConfig(
          gradientColors: [Colors.purple.shade50, Colors.deepPurple.shade50],
          borderColor: Colors.purple.shade200,
          shadowColor: Colors.purple,
          decorativeColor1: Colors.purple.shade100.withOpacity(0.3),
          decorativeColor2: Colors.deepPurple.shade100.withOpacity(0.4),
          icon: Icons.campaign_rounded,
          iconColor: Colors.purple.shade600,
          iconGradientColors: [
            Colors.purple.shade600,
            Colors.deepPurple.shade500,
          ],
          titleColor: Colors.purple.shade800,
          contentColor: Colors.purple.shade900,
          contentBorderColor: Colors.purple.shade100,
        );
    }
  }
}

class _NoticeConfig {
  final List<Color> gradientColors;
  final Color borderColor;
  final Color shadowColor;
  final Color decorativeColor1;
  final Color decorativeColor2;
  final IconData icon;
  final Color iconColor;
  final List<Color> iconGradientColors;
  final Color titleColor;
  final Color contentColor;
  final Color contentBorderColor;

  _NoticeConfig({
    required this.gradientColors,
    required this.borderColor,
    required this.shadowColor,
    required this.decorativeColor1,
    required this.decorativeColor2,
    required this.icon,
    required this.iconColor,
    required this.iconGradientColors,
    required this.titleColor,
    required this.contentColor,
    required this.contentBorderColor,
  });
}
