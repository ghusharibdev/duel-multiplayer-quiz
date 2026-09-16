import 'package:cloud_firestore/cloud_firestore.dart';

/// Seed questions into Firestore
/// Run this script to populate the questions collection
Future<void> seedQuestions() async {
  final questions = [
    {
      'text': 'What is the capital of France?',
      'options': ['London', 'Berlin', 'Paris', 'Madrid'],
      'correctIndex': 2,
      'category': 'Geography',
      'difficulty': 1,
    },
    {
      'text': 'Which planet is known as the Red Planet?',
      'options': ['Venus', 'Mars', 'Jupiter', 'Saturn'],
      'correctIndex': 1,
      'category': 'Science',
      'difficulty': 1,
    },
    {
      'text': 'What is the largest ocean on Earth?',
      'options': ['Atlantic', 'Indian', 'Arctic', 'Pacific'],
      'correctIndex': 3,
      'category': 'Geography',
      'difficulty': 1,
    },
    {
      'text': 'Who painted the Mona Lisa?',
      'options': ['Van Gogh', 'Picasso', 'Da Vinci', 'Monet'],
      'correctIndex': 2,
      'category': 'Art',
      'difficulty': 1,
    },
    {
      'text': 'What is the chemical symbol for gold?',
      'options': ['Go', 'Gd', 'Au', 'Ag'],
      'correctIndex': 2,
      'category': 'Science',
      'difficulty': 2,
    },
    {
      'text': 'Which country has the most population?',
      'options': ['USA', 'India', 'China', 'Russia'],
      'correctIndex': 2,
      'category': 'Geography',
      'difficulty': 2,
    },
    {
      'text': 'What year did World War II end?',
      'options': ['1943', '1944', '1945', '1946'],
      'correctIndex': 2,
      'category': 'History',
      'difficulty': 2,
    },
    {
      'text': 'What is the speed of light?',
      'options': ['300,000 km/s', '150,000 km/s', '500,000 km/s', '100,000 km/s'],
      'correctIndex': 0,
      'category': 'Science',
      'difficulty': 2,
    },
    {
      'text': 'Which element has the atomic number 1?',
      'options': ['Helium', 'Hydrogen', 'Lithium', 'Carbon'],
      'correctIndex': 1,
      'category': 'Science',
      'difficulty': 1,
    },
    {
      'text': 'What is the largest mammal?',
      'options': ['Elephant', 'Blue Whale', 'Giraffe', 'Hippopotamus'],
      'correctIndex': 1,
      'category': 'Nature',
      'difficulty': 1,
    },
    {
      'text': 'Which programming language was created by James Gosling?',
      'options': ['Python', 'C++', 'Java', 'JavaScript'],
      'correctIndex': 2,
      'category': 'Technology',
      'difficulty': 2,
    },
    {
      'text': 'What is the currency of Japan?',
      'options': ['Yuan', 'Won', 'Yen', 'Ringgit'],
      'correctIndex': 2,
      'category': 'Geography',
      'difficulty': 1,
    },
    {
      'text': 'How many continents are there?',
      'options': ['5', '6', '7', '8'],
      'correctIndex': 2,
      'category': 'Geography',
      'difficulty': 1,
    },
    {
      'text': 'What is the hardest natural substance?',
      'options': ['Gold', 'Iron', 'Diamond', 'Platinum'],
      'correctIndex': 2,
      'category': 'Science',
      'difficulty': 1,
    },
    {
      'text': 'Which planet has the most moons?',
      'options': ['Jupiter', 'Saturn', 'Uranus', 'Neptune'],
      'correctIndex': 1,
      'category': 'Science',
      'difficulty': 3,
    },
    {
      'text': 'What is the main language spoken in Brazil?',
      'options': ['Spanish', 'Portuguese', 'French', 'English'],
      'correctIndex': 1,
      'category': 'Geography',
      'difficulty': 1,
    },
    {
      'text': 'Who wrote "Romeo and Juliet"?',
      'options': ['Dickens', 'Shakespeare', 'Austen', 'Twain'],
      'correctIndex': 1,
      'category': 'Literature',
      'difficulty': 1,
    },
    {
      'text': 'What is the square root of 144?',
      'options': ['10', '11', '12', '13'],
      'correctIndex': 2,
      'category': 'Mathematics',
      'difficulty': 1,
    },
    {
      'text': 'Which organ pumps blood through the body?',
      'options': ['Lungs', 'Brain', 'Heart', 'Liver'],
      'correctIndex': 2,
      'category': 'Science',
      'difficulty': 1,
    },
    {
      'text': 'What is the smallest prime number?',
      'options': ['0', '1', '2', '3'],
      'correctIndex': 2,
      'category': 'Mathematics',
      'difficulty': 1,
    },
    {
      'text': 'In which year did the Titanic sink?',
      'options': ['1910', '1911', '1912', '1913'],
      'correctIndex': 2,
      'category': 'History',
      'difficulty': 2,
    },
    {
      'text': 'What is the chemical formula for water?',
      'options': ['HO2', 'H2O', 'CO2', 'O2'],
      'correctIndex': 1,
      'category': 'Science',
      'difficulty': 1,
    },
    {
      'text': 'Which continent is Egypt in?',
      'options': ['Asia', 'Europe', 'Africa', 'South America'],
      'correctIndex': 2,
      'category': 'Geography',
      'difficulty': 1,
    },
    {
      'text': 'What is the largest planet in our solar system?',
      'options': ['Saturn', 'Jupiter', 'Neptune', 'Uranus'],
      'correctIndex': 1,
      'category': 'Science',
      'difficulty': 1,
    },
    {
      'text': 'Who developed the theory of relativity?',
      'options': ['Newton', 'Einstein', 'Hawking', 'Bohr'],
      'correctIndex': 1,
      'category': 'Science',
      'difficulty': 2,
    },
    {
      'text': 'What is the capital of Australia?',
      'options': ['Sydney', 'Melbourne', 'Canberra', 'Brisbane'],
      'correctIndex': 2,
      'category': 'Geography',
      'difficulty': 2,
    },
    {
      'text': 'How many bones are in the human body?',
      'options': ['106', '186', '206', '256'],
      'correctIndex': 2,
      'category': 'Science',
      'difficulty': 3,
    },
    {
      'text': 'What is the freezing point of water in Celsius?',
      'options': ['-10°C', '0°C', '10°C', '32°C'],
      'correctIndex': 1,
      'category': 'Science',
      'difficulty': 1,
    },
    {
      'text': 'Which country is known as the Land of the Rising Sun?',
      'options': ['China', 'Korea', 'Japan', 'Thailand'],
      'correctIndex': 2,
      'category': 'Geography',
      'difficulty': 1,
    },
    {
      'text': 'What is the largest desert in the world?',
      'options': ['Sahara', 'Gobi', 'Arabian', 'Antarctic'],
      'correctIndex': 3,
      'category': 'Geography',
      'difficulty': 2,
    },
  ];

  final batch = FirebaseFirestore.instance.batch();
  
  for (final question in questions) {
    final docRef = FirebaseFirestore.instance.collection('questions').doc();
    batch.set(docRef, question);
  }

  await batch.commit();
  print('Successfully seeded ${questions.length} questions!');
}

void main() async {
  // Uncomment to run seeder
  // await seedQuestions();
}
