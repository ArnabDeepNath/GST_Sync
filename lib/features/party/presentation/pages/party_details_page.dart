import 'package:flutter/material.dart';
import 'package:gspappv2/features/party/domain/models/party.dart';

class PartyDetailsPage extends StatefulWidget {
  final Party party;

  const PartyDetailsPage({super.key, required this.party});

  // Add named constructor for details
  const PartyDetailsPage.details({super.key, required this.party}) : super();

  @override
  State<PartyDetailsPage> createState() => _PartyDetailsPageState();
}

class _PartyDetailsPageState extends State<PartyDetailsPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Back button row
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit),
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFilingHealthCheck(),
                  const SizedBox(height: 16),
                  _buildGSTINCredentials(),
                  const SizedBox(height: 16),
                  _buildContact(),
                  const SizedBox(height: 16),
                  _buildCommunication(),
                ],
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilingHealthCheck() {
    return _buildSection(
      'FILING HEALTH CHECK',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                  Icons.check_circle_outline, 'ON TIME', Colors.green),
              _buildStatusItem(Icons.warning_outlined, 'LATE', Colors.orange),
              _buildStatusItem(Icons.pending_outlined, 'TO DO', Colors.blue),
              _buildStatusItem(Icons.error_outline, 'MISSED', Colors.red),
              _buildStatusItem(Icons.block_outlined, 'N/A', Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          _buildFilingSection(
            'GSTR-1',
            'Deadline was 11 Feb 2025',
            '2 DAYS OVERDUE',
            months: [
              'Jan',
              'Dec',
              'Nov',
              'Oct',
              'Sep',
              'Aug',
              'Jul',
              'Jun',
              'May',
              'Apr',
              'Mar',
              'Feb'
            ],
            statuses: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
          ),
          const SizedBox(height: 24),
          _buildFilingSection(
            'GSTR-3B',
            'Next on 20 Feb 2025',
            '7 DAYS LEFT',
            months: [
              'Jan',
              'Dec',
              'Nov',
              'Oct',
              'Sep',
              'Aug',
              'Jul',
              'Jun',
              'May',
              'Apr',
              'Mar',
              'Feb'
            ],
            statuses: [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilingSection(
    String title,
    String deadline,
    String status, {
    required List<String> months,
    required List<int> statuses,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              deadline,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(12, (index) {
            final color = statuses[index] == 1 ? Colors.green : Colors.blue;
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 96) /
                  6, // Adjust width based on screen size
              child: Column(
                children: [
                  Icon(
                    statuses[index] == 1
                        ? Icons.check_circle_outline
                        : Icons.pending_outlined,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    months[index],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '24',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildGSTINCredentials() {
    return _buildSection(
      'GSTIN CREDENTIALS',
      tag: 'PENDING',
      tagColor: Colors.orange,
      subtitle:
          'Add GSTIN credentials to download reports, create and check challan status faster!',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoField('Display Name', widget.party.name),
          _buildInfoField('Branch Name', 'Jharkhand'),
          _buildInfoField('Username', '--'),
          _buildInfoField('Password', '--'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.lock, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(
                'Stored with 256 bit encryption securely',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEditButton(),
        ],
      ),
    );
  }

  Widget _buildContact() {
    return _buildSection(
      'CONTACT',
      tag: 'PENDING',
      tagColor: Colors.orange,
      subtitle:
          'Add contact details to seamlessly share reminders, challans, reports and more!',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoField('Phone Number', widget.party.phone ?? '--'),
          _buildInfoField('Email Address', widget.party.email ?? '--'),
          const SizedBox(height: 16),
          _buildEditButton(),
        ],
      ),
    );
  }

  Widget _buildCommunication() {
    return _buildSection(
      'COMMUNICATION',
      child: Column(
        children: [
          ListTile(
            title: const Text('Send reminder to client'),
            subtitle:
                const Text('Payment of challan, request data, share reports'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          _buildButton('REMIND NOW'),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title, {
    String? tag,
    Color? tagColor,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (tag != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tagColor?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: tagColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
          side: const BorderSide(color: Colors.blue),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('EDIT DETAILS'),
      ),
    );
  }

  Widget _buildButton(String label) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
          side: const BorderSide(color: Colors.blue),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem('DETAILS', 0),
          _buildNavItem('REPORTS', 1),
          _buildNavItem('CHALLANS', 2),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
