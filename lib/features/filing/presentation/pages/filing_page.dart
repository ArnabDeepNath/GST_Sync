import 'package:flutter/material.dart';

class FilingPage extends StatelessWidget {
  const FilingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filing Page',
              style: Theme.of(context).textTheme.headlineMedium),
          // Add your filing page content here
        ],
      ),
    );
  }
}
