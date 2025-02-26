// ignore_for_file: use_build_context_synchronously, empty_catches

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MCQ App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthScreen(),
    );
  }
}

class AuthScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: Center(
          child: Text('Login/Signup'),
        ),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  await _auth.signInAnonymously();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => CategoryScreen()),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              },
              child: Text('Continue as Guest'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                );
              },
              child: Text('Sign Up'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _signUp() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CategoryScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepOrangeAccent,
      appBar: AppBar(
        title: Text('Sign Up'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUp,
                child: Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CategoryScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                child: Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryScreen extends StatelessWidget {
  final List<String> categories = ["BCS", "Primary", "NTRCA"];

  CategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Select Category'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              categories[index],
              style: TextStyle(fontSize: 24),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MCQScreen(category: categories[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MCQScreen extends StatefulWidget {
  final String category;

  const MCQScreen({super.key, required this.category});

  @override
  MCQScreenState createState() => MCQScreenState();
}

class MCQScreenState extends State<MCQScreen> {
  int currentQuestionIndex = 0;
  double score = 0;
  int correctAnswers = 0;
  int incorrectAnswers = 0;
  int skippedQuestions = 0;
  bool isQuizFinished = false;
  int timeLeft = 30; // Timer set to 30 seconds per question
  late Timer _timer;
  double highScore = 0;
  late AudioPlayer _audioPlayer;

  final Map<String, List<Map<String, dynamic>>> categorizedQuestions = {
    "BCS": [
      {
        'question': 'What is the capital of France?',
        'answers': ['Paris', 'London', 'Berlin', 'Madrid'],
        'correctAnswer': 'Paris',
        'hint': 'It is known as the "City of Light".',
      },
      {
        'question': 'Who wrote "To Kill a Mockingbird"?',
        'answers': [
          'Harper Lee',
          'Mark Twain',
          'J.K. Rowling',
          'Ernest Hemingway'
        ],
        'correctAnswer': 'Harper Lee',
        'hint': 'She was born in Alabama.',
      },
    ],
    "Primary": [
      {
        'question': 'Mars is known as the Red Planet.',
        'answers': ['True', 'False'],
        'correctAnswer': 'True',
        'hint': 'It is the fourth planet from the Sun.',
      },
      {
        'question': 'What is the chemical symbol for water?',
        'answers': ['H2O', 'O2', 'CO2', 'NaCl'],
        'correctAnswer': 'H2O',
        'hint': 'It consists of two hydrogen atoms and one oxygen atom.',
      },
    ],
    "NTRCA": [
      {
        'question': 'Who was the first President of the United States?',
        'answers': [
          'George Washington',
          'Thomas Jefferson',
          'Abraham Lincoln',
          'John Adams'
        ],
        'correctAnswer': 'George Washington',
        'hint': 'He is known as the "Father of His Country".',
      },
      {
        'question': 'In which year did World War II end?',
        'answers': ['1945', '1939', '1918', '1965'],
        'correctAnswer': '1945',
        'hint': 'It ended with the surrender of Japan.',
      },
    ],
  };

  late List<Map<String, dynamic>> questions;

  @override
  void initState() {
    super.initState();
    questions = categorizedQuestions[widget.category]!;
    _audioPlayer = AudioPlayer();
    startTimer();
    loadHighScore();
  }

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        setState(() {
          timeLeft--;
        });
      } else {
        timer.cancel();
        skippedQuestions++;
        moveToNextQuestion();
      }
    });
  }

  void answerQuestion(String selectedAnswer) {
    _timer.cancel(); // Stop the timer when an answer is selected
    if (selectedAnswer == questions[currentQuestionIndex]['correctAnswer']) {
      setState(() {
        score++;
        correctAnswers++;
      });
      _playSound('correct.mp3');
    } else {
      setState(() {
        score -= 0.25; // Apply negative marking
        incorrectAnswers++;
      });
      _playSound('wrong.mp3');
    }
    moveToNextQuestion();
  }

  void skipQuestion() {
    _timer.cancel(); // Stop the timer when the question is skipped
    skippedQuestions++;
    moveToNextQuestion();
  }

  void moveToNextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        timeLeft = 30; // Reset timer for the next question
        startTimer();
      });
    } else {
      setState(() {
        isQuizFinished = true;
        saveHighScore();
      });
    }
  }

  void resetQuiz() {
    setState(() {
      currentQuestionIndex = 0;
      score = 0;
      correctAnswers = 0;
      incorrectAnswers = 0;
      skippedQuestions = 0;
      isQuizFinished = false;
      timeLeft = 30;
      startTimer();
    });
  }

  void loadHighScore() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getDouble('highScore') ?? 0;
    });
  }

  void saveHighScore() async {
    if (score > highScore) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('highScore', score);
      setState(() {
        highScore = score;
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('leaderboard').add({
        'user': user.email ?? user.uid,
        'score': score,
        'timestamp': FieldValue.serverTimestamp(),
        // ignore: body_might_complete_normally_catch_error
      }).catchError((error) {});
    }
  }

  void showHintDialog(String hint) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Hint'),
          content: Text(hint),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _playSound(String sound) async {
    try {
      await _audioPlayer.play(AssetSource(sound));
    } catch (e) {}
  }

  @override
  void dispose() {
    _timer.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MCQ App - ${widget.category}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Time: $timeLeft',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: isQuizFinished
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Quiz Finished!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Your Score: $score/${questions.length}',
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Correct Answers: $correctAnswers',
                    style: TextStyle(fontSize: 20, color: Colors.green),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Incorrect Answers: $incorrectAnswers',
                    style: TextStyle(fontSize: 20, color: Colors.red),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Skipped Questions: $skippedQuestions',
                    style: TextStyle(fontSize: 20, color: Colors.orange),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'High Score: $highScore',
                    style: TextStyle(fontSize: 20, color: Colors.blue),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: resetQuiz,
                    child: Text('Restart Quiz'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(
                    value: (currentQuestionIndex + 1) / questions.length,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation(Colors.blue),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Question ${currentQuestionIndex + 1}/${questions.length}',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 20),
                  Text(
                    questions[currentQuestionIndex]['question'],
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  ...(questions[currentQuestionIndex]['answers']
                          as List<String>)
                      .map((answer) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ElevatedButton(
                              onPressed: () => answerQuestion(answer),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                answer,
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          )),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () =>
                        showHintDialog(questions[currentQuestionIndex]['hint']),
                    child: Text('Show Hint'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: skipQuestion,
                    child: Text('Skip Question'),
                  ),
                ],
              ),
            ),
    );
  }
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leaderboard')
            .orderBy('score', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else {
            final scores = snapshot.data!.docs;
            return ListView.builder(
              itemCount: scores.length,
              itemBuilder: (context, index) {
                final score = scores[index]['score'];
                final user = scores[index]['user'];
                return ListTile(
                  title: Text('User: $user'),
                  subtitle: Text('Score: $score'),
                );
              },
            );
          }
        },
      ),
    );
  }
}
