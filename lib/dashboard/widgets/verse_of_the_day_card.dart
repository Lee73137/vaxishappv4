import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

class _Verse {
  const _Verse({required this.text, required this.reference});

  final String text;
  final String reference;
}

class VerseOfTheDayCard extends StatefulWidget {
  const VerseOfTheDayCard({super.key});

  @override
  State<VerseOfTheDayCard> createState() => _VerseOfTheDayCardState();
}

class _VerseOfTheDayCardState extends State<VerseOfTheDayCard> {
  bool _isLoading = true;
  _Verse? _verse;

  @override
  void initState() {
    super.initState();
    _fetchVerse();
  }

  Future<void> _fetchVerse() async {
    try {
      final response = await http
          .get(Uri.parse('https://labs.bible.org/api/?passage=votd&type=json'))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _verse = data.isEmpty ? null : _parseVerse(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _verse = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      // Non-critical decorative content — fail silently and just don't
      // show the card, rather than surfacing an error to the user.
      if (!mounted) return;
      setState(() {
        _verse = null;
        _isLoading = false;
      });
    }
  }

  _Verse _parseVerse(List<dynamic> data) {
    final text = data
        .map((entry) => (entry['text'] as String?)?.trim() ?? '')
        .join(' ')
        .trim();

    final first = data.first;
    final last = data.last;
    final book = first['bookname'];
    final chapter = first['chapter'];
    final firstVerse = first['verse'];
    final lastVerse = last['verse'];

    final reference = firstVerse == lastVerse
        ? '$book $chapter:$firstVerse'
        : '$book $chapter:$firstVerse-$lastVerse';

    return _Verse(text: text, reference: reference);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: SizedBox(
            width: 18.w,
            height: 18.w,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade700),
            ),
          ),
        ),
      );
    }

    final verse = _verse;
    if (verse == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4.w,
            height: 52.h,
            decoration: BoxDecoration(
              color: Colors.amber.shade600,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 14.sp,
                      color: Colors.amber.shade800,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Verse of the Day',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  '"${verse.text}"',
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                    color: const Color(0xFF3D3221),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  verse.reference,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
