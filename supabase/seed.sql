-- Run after the schema migration. Safe to rerun; existing edits are preserved.
insert into public.topic_packs (id, name, words, is_published) values
  ('food', 'Food & drink', array['Pizza', 'Sushi', 'Tacos', 'Pasta', 'Burger', 'Salad', 'Pancakes', 'Popcorn', 'Chocolate', 'Ice cream', 'Coffee', 'Lemonade'], true),
  ('places', 'Out & about', array['Beach', 'Library', 'Museum', 'Airport', 'Stadium', 'Cinema', 'Park', 'Hospital', 'Bakery', 'Zoo', 'School', 'Mountain'], true),
  ('hobbies', 'After class', array['Gaming', 'Cooking', 'Dancing', 'Reading', 'Hiking', 'Painting', 'Singing', 'Swimming', 'Gardening', 'Photography', 'Cycling', 'Camping'], true),
  ('animals', 'Animal kingdom', array['Lion', 'Elephant', 'Giraffe', 'Zebra', 'Penguin', 'Dolphin', 'Shark', 'Owl', 'Rabbit', 'Turtle', 'Octopus', 'Butterfly'], true),
  ('sports', 'Game day', array['Soccer', 'Basketball', 'Baseball', 'Tennis', 'Golf', 'Hockey', 'Volleyball', 'Boxing', 'Bowling', 'Surfing', 'Skiing', 'Gymnastics'], true),
  ('jobs', 'On the job', array['Doctor', 'Teacher', 'Chef', 'Pilot', 'Firefighter', 'Dentist', 'Farmer', 'Plumber', 'Architect', 'Librarian', 'Mechanic', 'Veterinarian'], true),
  ('transport', 'Getting around', array['Car', 'Bus', 'Train', 'Bicycle', 'Motorcycle', 'Airplane', 'Helicopter', 'Ferry', 'Submarine', 'Scooter', 'Tram', 'Hot air balloon'], true),
  ('space', 'Outer space', array['Sun', 'Moon', 'Mars', 'Saturn', 'Comet', 'Asteroid', 'Galaxy', 'Black hole', 'Rocket', 'Astronaut', 'Satellite', 'Telescope'], true),
  ('music', 'Music room', array['Piano', 'Guitar', 'Violin', 'Drums', 'Flute', 'Trumpet', 'Saxophone', 'Harp', 'Cello', 'Clarinet', 'Accordion', 'Tambourine'], true),
  ('weather', 'Wild weather', array['Rain', 'Snow', 'Hail', 'Fog', 'Thunder', 'Lightning', 'Rainbow', 'Tornado', 'Hurricane', 'Blizzard', 'Drought', 'Heatwave'], true)
on conflict (id) do nothing;
