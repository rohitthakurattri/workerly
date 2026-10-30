module Adapters
  module Ai
    # Development/test adapter: keyword rules instead of a model, so triage works offline and
    # deterministically. English, Hindi and common romanised Hindi/Punjabi words.
    class Fake
      KEYWORDS = {
        "plumber" => %w[tap leak leaking pipe drain blocked toilet flush geyser tank basin sink nal नल पाइप पानी टंकी लीक nalka ਨਲ ਪਾਣੀ],
        "electrician" => %w[switch wiring wire fan light socket mcb fuse inverter spark sparking bijli pankha बिजली पंखा स्विच तार ਬਿਜਲੀ ਪੱਖਾ],
        "carpenter" => %w[door wood furniture cupboard wardrobe bed hinge drawer lock darwaza दरवाज़ा दरवाजा लकड़ी अलमारी ਦਰਵਾਜ਼ਾ ਲੱਕੜ],
        "ac-repair" => %w[ac a/c cooling compressor gas-filling split window-ac एसी ਏਸੀ],
        "painter" => %w[paint painting wall walls putty colour color damp seepage पेंट दीवार ਪੇਂਟ ਕੰਧ],
        "appliance-repair" => %w[fridge refrigerator washing machine microwave ro purifier chimney oven फ्रिज वॉशिंग ਫਰਿੱਜ]
      }.freeze
      SAFETY = %w[gas spark sparking smoke burning fire shock flood flooding current करंट धुआं आग ਕਰੰਟ ਅੱਗ].freeze
      QUESTIONS = {
        "plumber" => [ "Where is the problem (kitchen, bathroom, outside)?", "Is water leaking right now?" ],
        "electrician" => [ "Which appliance or point is affected?", "Has the MCB or fuse tripped?" ],
        "carpenter" => [ "What needs fixing or making?", "Roughly what size is it?" ],
        "ac-repair" => [ "Is it a split or window AC?", "What is the brand and roughly how old is it?" ],
        "painter" => [ "How many rooms or walls?", "Is there damp or peeling paint?" ],
        "appliance-repair" => [ "What is the appliance and brand?", "What happens when you switch it on?" ]
      }.freeze

      def name = "fake"
      def supports_images? = false

      def complete(use_case:, vars:, **)
        raise Error.new(:not_configured, "fake adapter has no #{use_case}") unless use_case == "triage"

        Response.new(output: triage(vars), model: "fake-rules-1", input_tokens: nil, output_tokens: nil)
      end

      private

      def triage(vars)
        slugs = vars[:categories].to_s.lines.map { |l| l.split(":").first.strip }
        words = vars[:description].to_s.downcase.split(/[^[:alnum:]\/\-]+/)
        scores = slugs.to_h { |slug| [ slug, (KEYWORDS.fetch(slug, []) & words).size ] }.select { |_, s| s.positive? }
        ranked = scores.sort_by { |slug, s| [ -s, slugs.index(slug) ] }.map(&:first)
        best = ranked.first
        clear_winner = best && (ranked.size == 1 || scores[best] > scores[ranked[1]])
        safety = SAFETY.intersect?(words)
        {
          "category_slug" => best,
          "confidence" => best.nil? ? 0.0 : (clear_winner ? 0.9 : 0.5),
          "alternatives" => ranked.drop(1).first(3),
          "problem_summary" => best ? "#{best.tr("-", " ").capitalize} job: #{vars[:description].to_s.strip.truncate(120)}" : "",
          "follow_up_questions" => QUESTIONS.fetch(best, []),
          "urgency" => safety || words.intersect?(%w[urgent emergency now jaldi turant]) ? "asap" : "flexible",
          "safety_flag" => safety
        }
      end
    end
  end
end
