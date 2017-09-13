p "Clearing the DB..."

Review.delete_all # always remove children first!
Language.delete_all


p "Creating languages..."

Language.create!(
  [
    {
      name: 'Ruby',
      description: 'The awesomest programming language ever. Le Wagon favourite.'
    },
    {
      name: 'JavaScript',
      description: "The only language that runs in the browser. You'll be lost without in a modern Web."
    },
    {
      name: 'HTML',
      description: 'Technically not a programming language. Gives structure to your web pages.'
    },
    {
      name: 'CSS',
      description: 'Deceptively easy in concept, incredibly hard to truly master. Not many people like it.'
    },
    {
      name: 'SQL',
      description: "That's how you talk to your data! Take time to master it even without ActiveRecord."
    }
  ]
)

p "Creating reviews..."

Language.find_each do |lang|
  lang.reviews.build([
    { content: 'I really enjoyed learning this one at Le Wagon! Never stop learning!' },
    { content: 'Wish I could do more of it!'},
    { content: 'Still having some trouble with it, but practice makes perfect.'}
  ])
  lang.save
end
