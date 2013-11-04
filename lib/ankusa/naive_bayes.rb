module Ankusa
  INFTY = 1.0 / 0.0

  class NaiveBayesClassifier
    include Classifier

    def classify(text, classes=nil)
      # return the most probable class
      result = log_likelihoods(text, classes)
      if result.values.uniq.size. === 1
        # unless all classes are equally likely, then return nil
        return nil
      else
        result.sort_by { |c| -c[1] }.first.first
      end
    end

    # Classes is an array of classes to look at
    def classifications(text, classnames=nil)
      result = log_likelihoods text, classnames
      result.keys.each { |k|
        result[k] = (result[k] == -INFTY) ? 0 : Math.exp(result[k])
      }

      # normalize to get probs
      sum = result.values.inject{ |x,y| x+y }
      result.keys.each { |k|
        result[k] = result[k] / sum
        } unless sum.zero?
      result
    end

    # Classes is an array of classes to look at
    def log_likelihoods(text, classnames=nil)
      classnames ||= @classnames
      @result = Hash.new 0
      calculate_prior(classnames)

      binding.pry
      calculate_frequency(text, classnames)

      binding.pry
      @result
    end

    def calculate_prior(classnames)
      doc_counts = doc_count_totals.select { |k,v| classnames.include? k }.map { |k,v| v }
      doc_count_total = (doc_counts.inject(0){ |x,y| x+y }).to_f

      classnames.each do |classname|
        @result[classname] += Math.log((@storage.get_doc_count(classname) + 1).to_f / doc_count_total)
      end
    end

    def calculate_frequency(text, classnames)
      th = TextHash.new(text)
      words = th.map { |word, count| word }
      probs = multi_get_word_probs(words, classnames)

      th.each do |word_array|
        word, count = word_array.first, word_array.last
        prob = probs[word]

        next if prob.nil?

        classnames.each do |k|
          # log likelihood should be negative infinity if we've never seen the klass
          @result[k] += prob[k] > 0 ? (Math.log(prob[k]) * count) : -INFTY
        end
      end
    end

  end
end
