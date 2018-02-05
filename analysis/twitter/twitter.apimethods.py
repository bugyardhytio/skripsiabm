import tweepy

# Set your credentials as explained in the Authentication section
consumer_key = "GG3j4A0jpSGXBt9D7aM4QzdBV"
consumer_secret = "SsYRzE2on0xLWwPZ70Mi7YUabcaBaoohUFYlyEVjiw7mF5cFGB"

# Access tokens are needed only for operations that require authenticated requests
access_key = "56752482-SCCOZb6fwCithQCybxdKU9gXJ1QjLmUirs1X5BztH"
access_secret = "QbjUaHmVov7QTCNCNIuMOrVgnwXxD38JMwklGpANBb1Y1"

# Set up your client
auth = tweepy.OAuthHandler(consumer_key, consumer_secret)
auth.set_access_token(access_key, access_secret)
api = tweepy.API(auth)

# Get some tweets around a center point (see http://docs.tweepy.org/en/v3.5.0/api.html#API.search)
tweets = api.search(geocode='60.1694461,24.9527073,1km')

# Print all tweets
for tweet in tweets:
    print "%s said: %s at %s. Location: %s" % (tweet.user.screen_name, tweet.text, tweet.created_at, tweet.coordinates['coordinates'])
    print "---"