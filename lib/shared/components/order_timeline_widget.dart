import 'package:flutter/material.dart';

class OrderTimelineWidget extends StatefulWidget {
  final List<OrderTimelineStep> steps;
  final Color statusColor;
  final bool showAnimations;
  final bool showStepLabels;
  final double? iconSize;
  final double? lineHeight;

  const OrderTimelineWidget({
    super.key,
    required this.steps,
    required this.statusColor,
    this.showAnimations = true,
    this.showStepLabels = false,
    this.iconSize,
    this.lineHeight,
  });

  @override
  State<OrderTimelineWidget> createState() => _OrderTimelineWidgetState();
}

class _OrderTimelineWidgetState extends State<OrderTimelineWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _lineAnimationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _lineAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _lineAnimationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    _lineAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _lineAnimationController,
      curve: Curves.easeInOut,
    ));

    if (widget.showAnimations) {
      // Start animations
      _progressAnimationController.forward();
      _pulseAnimationController.repeat(reverse: true);
      _lineAnimationController.repeat();
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _pulseAnimationController.dispose();
    _lineAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: widget.showAnimations ? _progressAnimation : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Column(
          children: [
            // Timeline Row
            Row(
              children: [
                // Build timeline with alternating icons and lines
                for (int i = 0; i < widget.steps.length; i++) ...[
                  // Step Icon
                  _buildStepIcon(theme, widget.steps[i], i),
                  
                  // Connecting Line (except for last item)
                  if (i < widget.steps.length - 1)
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width < 768 ? 4 : 8,
                        ),
                        child: _buildConnectingLine(theme, widget.steps[i], i),
                      ),
                    ),
                ],
              ],
            ),

            // Step Labels (optional)
            if (widget.showStepLabels) ...[
              const SizedBox(height: 12),
              Row(
                children: widget.steps.asMap().entries.map((entry) {
                  final step = entry.value;

                  return Expanded(
                    child: Text(
                      step.title,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight:
                            step.isCompleted ? FontWeight.w600 : FontWeight.w400,
                        color: step.isCompleted 
                            ? widget.statusColor 
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStepIcon(ThemeData theme, OrderTimelineStep step, int index) {
    final isActive = step.isCompleted;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    // Responsive sizes
    final iconContainerSize = widget.iconSize ?? (isMobile ? 25.0 : 40.0);
    final iconSize = (widget.iconSize ?? (isMobile ? 25.0 : 40.0)) * 0.6;

    // Current step is the first incomplete step
    bool isCurrentStep = false;
    if (!step.isCompleted) {
      // Find the first incomplete step
      int firstIncompleteIndex = -1;
      for (int i = 0; i < widget.steps.length; i++) {
        if (!widget.steps[i].isCompleted) {
          firstIncompleteIndex = i;
          break;
        }
      }
      isCurrentStep = index == firstIncompleteIndex;
    }

    // Get icon based on step title
    IconData getStepIcon() {
      switch (step.title.toLowerCase()) {
        case 'order on cart':
          return Icons.shopping_cart;
        case 'payment':
          return Icons.payment;
        case 'preparing':
          return Icons.restaurant;
        case 'ready':
        case 'ready for pickup':
          return Icons.shopping_bag;
        case 'out for delivery':
          return Icons.delivery_dining;
        case 'delivered':
          return Icons.check_circle;
        case 'canceled':
          return Icons.cancel;
        default:
          return step.icon ?? Icons.circle;
      }
    }

    return AnimatedBuilder(
      animation: (widget.showAnimations && isCurrentStep) ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        final scale = (widget.showAnimations && isCurrentStep) 
            ? (0.95 + 0.05 * _pulseAnimation.value) 
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: BoxDecoration(
              color: isActive
                  ? widget.statusColor
                  : isCurrentStep
                      ? widget.statusColor.withOpacity(0.2)
                      : theme.colorScheme.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive || isCurrentStep
                    ? widget.statusColor
                    : theme.colorScheme.outline,
                width: isCurrentStep ? (isMobile ? 2 : 3) : 2,
              ),
              boxShadow: (widget.showAnimations && isCurrentStep)
                  ? [
                      BoxShadow(
                        color: widget.statusColor.withOpacity(0.4),
                        blurRadius: isMobile ? 6 : 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                getStepIcon(),
                size: iconSize,
                color: isActive
                    ? Colors.white
                    : isCurrentStep
                        ? widget.statusColor
                        : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectingLine(ThemeData theme, OrderTimelineStep step, int index) {
    final isActive = step.isCompleted;
    final nextStep = index + 1 < widget.steps.length ? widget.steps[index + 1] : null;

    // Check if this is the current step (incomplete)
    final isCurrentStep = !step.isCompleted &&
        (index == 0 || (index > 0 && widget.steps[index - 1].isCompleted));

    // For completed steps, check if this step is the current active one
    final isCurrentCompletedStep = step.isCompleted &&
        nextStep != null &&
        !nextStep.isCompleted;

    final shouldShowAnimation = widget.showAnimations && (isCurrentStep || isCurrentCompletedStep);

    return AnimatedBuilder(
      animation: shouldShowAnimation ? _lineAnimation : const AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Container(
          height: widget.lineHeight ?? 4,
          width: double.infinity,
          child: Stack(
            children: [
              // Background line
              Container(
                height: widget.lineHeight ?? 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Completed progress line
              if (isActive)
                Container(
                  height: widget.lineHeight ?? 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: widget.statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

              // Animated flowing line for current step
              if (shouldShowAnimation && nextStep != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final progress = _lineAnimation.value;

                    return Stack(
                      children: [
                        // Base flowing line - reaches 100%
                        Container(
                          height: widget.lineHeight ?? 4,
                          width: maxWidth * progress, // Full line animation
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                widget.statusColor.withOpacity(0.2),
                                widget.statusColor,
                              ],
                              stops: const [0.0, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // Flowing dot
                        Positioned(
                          left: (maxWidth * progress).clamp(0.0, maxWidth - 8),
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: widget.statusColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.statusColor.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class OrderTimelineStep {
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime? timestamp;
  final IconData? icon;

  const OrderTimelineStep({
    required this.title,
    required this.description,
    required this.isCompleted,
    this.timestamp,
    this.icon,
  });

  factory OrderTimelineStep.fromOrderStatusStep(dynamic step) {
    return OrderTimelineStep(
      title: step.title,
      description: step.description,
      isCompleted: step.isCompleted,
      timestamp: step.timestamp,
    );
  }
}
