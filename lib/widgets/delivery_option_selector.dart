import 'package:flutter/material.dart';

class DeliveryOptionSelector extends StatelessWidget {
  final String selectedOption;
  final Function(String) onOptionChanged;
  final bool deliveryEnabled;
  final double deliveryFee;

  const DeliveryOptionSelector({
    Key? key,
    required this.selectedOption,
    required this.onOptionChanged,
    this.deliveryEnabled = true,
    this.deliveryFee = 50.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.delivery_dining,
                  color: Colors.deepPurple.shade700,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Choose Delivery Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Options
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Store Pickup Option
                _buildOptionCard(
                  context,
                  icon: Icons.store,
                  title: 'Store Pickup',
                  subtitle: 'Collect your order from the store',
                  price: 'Free',
                  value: 'pickup',
                  color: Colors.blue,
                  isSelected: selectedOption == 'pickup',
                ),

                SizedBox(height: 12),

                // Home Delivery Option
                _buildOptionCard(
                  context,
                  icon: Icons.delivery_dining,
                  title: 'Home Delivery',
                  subtitle: 'We\'ll deliver to your address',
                  price: '৳50',
                  value: 'delivery',
                  color: Colors.green,
                  isSelected: selectedOption == 'delivery',
                  isEnabled: deliveryEnabled,
                ),

                if (!deliveryEnabled)
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Delivery is currently disabled for this shop',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String price,
    required String value,
    required Color color,
    required bool isSelected,
    bool isEnabled = true,
  }) {
    return GestureDetector(
      onTap: isEnabled ? () => onOptionChanged(value) : null,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio Button
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? color : Colors.transparent,
              ),
              child:
                  isSelected
                      ? Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
            ),

            SizedBox(width: 16),

            // Icon
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),

            SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isEnabled ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled ? Colors.grey.shade600 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                price,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
