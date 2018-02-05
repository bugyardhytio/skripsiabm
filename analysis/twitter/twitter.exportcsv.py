import tweepy
import csv

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
tweets = api.search(geocode='-6.205537,106.83942540285217,50km')

data = {
    "username": "",
    "tweet_id": "",
    "text": "",
    "created_at": "",
    "location": ""
}
with open("tweet_export.csv", "wb") as csvfile:
    fieldnames = ["username", "tweet_id", "text", "created_at", "location"]
    writer = csv.DictWriter(csvfile, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL, fieldnames=fieldnames)
    writer.writeheader()
    for tweet in tweets:
        data["username"] = tweet.user.screen_name
        data["tweet_id"] = tweet.id
        data["text"] = tweet.text.encode('utf-8')
        data["created_at"] = str(tweet.created_at)
        data["location"] = tweet.coordinates
        writer.writerow(data)