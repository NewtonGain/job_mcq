import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(ProviderScope(child: MCQApp()));
}

class MCQApp extends StatelessWidget {
  const MCQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MCQ Quiz App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'Job MCQ',
            style: TextStyle(fontSize: 25),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildExamButton(context, 'BCS Exam', 'BCS'),
            _buildExamButton(context, 'NTRCA Exam', 'NTRCA'),
            _buildExamButton(context, 'Primary Exam', 'Primary'),
          ],
        ),
      ),
    );
  }

  Widget _buildExamButton(BuildContext context, String title, String examType) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubCategoryPage(examType: examType),
          ),
        );
      },
      child: Text(title),
    );
  }
}

class SubCategoryPage extends StatelessWidget {
  final String examType;

  const SubCategoryPage({super.key, required this.examType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$examType Exam Questions')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSubCategoryButton(context, '$examType 10', '10'),
            _buildSubCategoryButton(context, '$examType 2', '2'),
            _buildSubCategoryButton(context, '$examType 3', '3'),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryButton(
      BuildContext context, String title, String subCategory) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                QuestionScreen(examType: examType, subCategory: subCategory),
          ),
        );
      },
      child: Text(title),
    );
  }
}

class QuestionScreen extends ConsumerStatefulWidget {
  final String examType;
  final String subCategory;

  const QuestionScreen(
      {super.key, required this.examType, required this.subCategory});

  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  double score = 0;
  int wrongAttempts = 0;
  int skipCount = 0;
  bool submitted = false;
  Timer? timer;
  int timeRemaining = 30; // 30 seconds per question
  bool timeExpired = false;
  List<Map<String, dynamic>> answers = [];
  final ConfettiController _confettiController = ConfettiController();
  String? selectedAnswer;

  @override
  void initState() {
    super.initState();
    loadQuestions();
  }

  @override
  void dispose() {
    timer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> loadQuestions() async {
    try {
      final String response = await rootBundle.loadString(
          'assets/${widget.examType.toLowerCase()}_${widget.subCategory}_questions.json');
      final data = await json.decode(response);
      setState(() {
        questions = List<Map<String, dynamic>>.from(data);
      });
      startTimer();
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load questions: $e')),
      );
    }
  }

  void startTimer() {
    timeRemaining = 30;
    timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (timeRemaining == 0) {
        setState(() {
          timeExpired = true;
          submitted = true;
          timer.cancel();
        });
        handleNegativeMarking();
      } else {
        setState(() {
          timeRemaining--;
        });
      }
    });
  }

  void handleNegativeMarking() {
    if (timeExpired && currentQuestionIndex < questions.length) {
      wrongAttempts++;
      score -= 0.25; // Negative marking
    }
  }

  void handleAnswer(String answer) {
    setState(() {
      selectedAnswer = answer;
      submitted = true;
    });

    bool isCorrect =
        answer == questions[currentQuestionIndex]['correct_answer'];
    if (!isCorrect) {
      wrongAttempts++;
      score -= 0.25; // Negative marking
    } else {
      score++;
    }

    answers.add({
      'question': questions[currentQuestionIndex]['question'],
      'selected_answer': answer,
      'correct_answer': questions[currentQuestionIndex]['correct_answer'],
      'hint': questions[currentQuestionIndex]['hint'],
      'is_correct': isCorrect,
    });

    timer?.cancel();
    Future.delayed(Duration(seconds: 1), () {
      handleNext(); // Move to the next question automatically after a delay
    });
  }

  void skipQuestion() {
    answers.add({
      'question': questions[currentQuestionIndex]['question'],
      'selected_answer': 'Skipped',
      'correct_answer': questions[currentQuestionIndex]['correct_answer'],
      'hint': questions[currentQuestionIndex]['hint'],
      'is_correct': false,
    });
    setState(() {
      skipCount++;
      submitted = true;
      timer?.cancel();
    });
    handleNext(); // Move to the next question automatically
  }

  void handleNext() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        submitted = false;
        timeExpired = false;
        selectedAnswer = null;
        startTimer();
      });
    } else {
      setState(() {
        currentQuestionIndex++;
      });
    }
  }

  void showHint(String hint) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hint'),
          content: Text(hint),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Loading...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentQuestionIndex >= questions.length) {
      return ResultsPage(
        score: score,
        totalQuestions: questions.length,
        wrongAttempts: wrongAttempts,
        skipCount: skipCount,
        answers: answers,
        confettiController: _confettiController,
      );
    }

    var question = questions[currentQuestionIndex];

    return Scaffold(
      appBar:
          AppBar(title: Text('${widget.examType} ${widget.subCategory} Quiz')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QuestionCard(
              question: question['question'],
              timeRemaining: timeRemaining,
            ),
            SizedBox(height: 20),
            ...question['answers'].map<Widget>((answer) {
              return AnswerButton(
                answer: answer['text'],
                isCorrectAnswer: answer['text'] == question['correct_answer'],
                isSelectedAnswer: selectedAnswer == answer['text'],
                submitted: submitted,
                onPressed: () => handleAnswer(answer['text']),
              );
            }).toList(),
            SizedBox(height: 20),
            if (!submitted)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                      'Skip Question', Colors.orange, skipQuestion),
                  _buildActionButton('Show Hint', Colors.blue,
                      () => showHint(question['hint'])),
                ],
              ),
            if (submitted && answers.isNotEmpty)
              Column(
                children: [
                  Text(
                    timeExpired
                        ? 'Time Expired!'
                        : (answers.last['is_correct'] ? 'Correct!' : 'Wrong!'),
                    style: TextStyle(fontSize: 18),
                  ),
                  _buildActionButton('Next Question', Colors.green, handleNext),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      child: Text(text),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final String question;
  final int timeRemaining;

  const QuestionCard({
    super.key,
    required this.question,
    required this.timeRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              question,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: (timeRemaining / 30),
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 10),
            Text('Time Remaining: $timeRemaining seconds'),
          ],
        ),
      ),
    );
  }
}

class AnswerButton extends StatelessWidget {
  final String answer;
  final bool isCorrectAnswer;
  final bool isSelectedAnswer;
  final bool submitted;
  final VoidCallback onPressed;

  const AnswerButton({
    super.key,
    required this.answer,
    required this.isCorrectAnswer,
    required this.isSelectedAnswer,
    required this.submitted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 5),
      child: ElevatedButton(
        onPressed: submitted ? null : onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: submitted
              ? isCorrectAnswer
                  ? Colors.green
                  : isSelectedAnswer
                      ? Colors.red
                      : Colors.blueAccent
              : Colors.blueAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
        child: Text(answer),
      ),
    );
  }
}

class ResultsPage extends StatelessWidget {
  final double score;
  final int totalQuestions;
  final int wrongAttempts;
  final int skipCount;
  final List<Map<String, dynamic>> answers;
  final ConfettiController confettiController;

  const ResultsPage({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.wrongAttempts,
    required this.skipCount,
    required this.answers,
    required this.confettiController,
  });

  @override
  Widget build(BuildContext context) {
    if (score == totalQuestions) {
      confettiController.play(); // Trigger confetti for perfect score
    }

    return Scaffold(
      appBar: AppBar(title: Text('Results')),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Center(
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                margin: EdgeInsets.all(16.0),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Your Score: $score / $totalQuestions',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text('Wrong Attempts: $wrongAttempts',
                          style: TextStyle(fontSize: 18)),
                      Text('Questions Skipped: $skipCount',
                          style: TextStyle(fontSize: 18)),
                      SizedBox(height: 20),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: answers.length,
                        itemBuilder: (context, index) {
                          final answer = answers[index];
                          return Card(
                            elevation: 3,
                            margin: EdgeInsets.symmetric(vertical: 5),
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Q: ${answer['question']}',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      'Your Answer: ${answer['selected_answer']}',
                                      style: TextStyle(
                                          fontSize: 16,
                                          color: answer['is_correct']
                                              ? Colors.green
                                              : Colors.red)),
                                  Text(
                                      'Correct Answer: ${answer['correct_answer']}',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.blue)),
                                  Text('Hint: ${answer['hint']}',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 20),
                      _buildActionButton(
                          context, 'Restart Quiz', Colors.blueAccent, () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => HomePage()),
                        );
                      }),
                      _buildActionButton(context, 'Save Score', Colors.green,
                          () async {
                        try {
                          await FirebaseFirestore.instance
                              .collection('scores')
                              .add({
                            'score': score,
                            'totalQuestions': totalQuestions,
                            'wrongAttempts': wrongAttempts,
                            'skipCount': skipCount,
                            'timestamp': FieldValue.serverTimestamp(),
                          });
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Score saved!')));
                        } catch (e) {
                          // ignore: use_build_context_synchronously
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Failed to save score: $e')));
                        }
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: true,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      child: Text(text),
    );
  }
}
