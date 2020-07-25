#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <algorithm>

#define CLAMP(x, low, high)  (((x) > (high)) ? (high) : (((x) < (low)) ? (low) : (x)))

constexpr double percent(const double humanValue) {
	return humanValue / 100;
}

inline double calculateDistance(const unsigned char &r1,
						 const unsigned char &g1,
						 const unsigned char &b1,
						 const unsigned char &r2,
						 const unsigned char &g2,
						 const unsigned char &b2) {
	
	//Get the perceived colour distance.
	//Based on https://www.compuphase.com/cmetric.htm
	//The variables have been removed to give a significant performance boost when called a lot.
	//return sqrt((((512 + ((r1 + r2) / 2)) * (r1 - r2) * (r1 - r2)) >> 8) + 4 * (g1 - g2) * (g1 - g2) + (((767 - ((r1 + r2) / 2)) * (b1 - b2) * (b1 - b2)) >> 8));
	
	return sqrt((((512 + ((r1 + r2) >> 1)) * (r1 - r2) * (r1 - r2)) >> 8) + 4 * (g1 - g2) * (g1 - g2) + (((767 - ((r1 + r2) >> 1)) * (b1 - b2) * (b1 - b2)) >> 8));
}

bool pairSort(const std::pair<unsigned, std::vector<unsigned>> &l, const std::pair<unsigned, std::vector<unsigned>> &r) {
	return l.second.size() > r.second.size();
}

inline std::vector<std::pair<unsigned, std::vector<unsigned>>> sortBins(std::unordered_map<unsigned, std::vector<unsigned>> &binMap) {
	std::vector<std::pair<unsigned, std::vector<unsigned>>> binVec(binMap.begin(), binMap.end());
	std::sort(binVec.begin(), binVec.end(), pairSort);
	
	return binVec;
}

static std::vector<UIColor *> lastColorBins;
static bool generateColorListOnly = false;
UIColor *dominantColor(UIImage *img, const int binCount, const double checkPercentage, bool seekVibrant, const double vibrancyIgnorePercentage = 0.003) {
	if(checkPercentage > 1.0f) return [UIColor blackColor]; //how tf do you check more pixels than there are in an image? 100% max
	
	const CFTimeInterval binStart = CACurrentMediaTime();
	NSLog(@"Creating bins at %f", binStart);
	
	//Create the bins.
	std::unordered_map<unsigned, std::vector<unsigned>> bins;
	//We end up creating binCount^3 bins.
	bins.reserve(pow(binCount, 3));
	
	const float bincrement = 255.0f / binCount;
	for(unsigned redMultiplier = 0; redMultiplier <= binCount; ++redMultiplier) {
		for(unsigned greenMultiplier = 0; greenMultiplier <= binCount; ++greenMultiplier) {
			for(unsigned blueMultiplier = 0; blueMultiplier <= binCount; ++blueMultiplier) {
				const unsigned red = CLAMP(redMultiplier * bincrement, 0, 255);
				const unsigned green = CLAMP(greenMultiplier * bincrement, 0, 255);
				const unsigned blue = CLAMP(blueMultiplier * bincrement, 0, 255);
				
				const unsigned thisBin = (red << 16) | (green << 8) | (blue << 0);
				
				//Set this bin's count to 0.
				bins[thisBin] = {};
			}
		}
	}
	
	const CFTimeInterval binEnd = CACurrentMediaTime();
	NSLog(@"Finished creating bins at %f; took %f seconds.", binEnd, binEnd - binStart);
	
	const CFTimeInterval pixelStart = CACurrentMediaTime();
	NSLog(@"Starting getting pixel data at %f.", pixelStart);
	
	//Get the pixel data.
	CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(img.CGImage));
	const unsigned long length = CFDataGetLength(pixelData);
	unsigned char *pixelBuffer = (unsigned char *)CFDataGetBytePtr(pixelData);
	
	const unsigned long pixelCount = length / 4;
	const CFTimeInterval pixelEnd = CACurrentMediaTime();
	NSLog(@"Finished getting pixel data at %f; took %f seconds.", pixelEnd, pixelEnd - pixelStart);
	
	//This will serve as a cache so that we don't have to work out bins for the same pixel colours over and over again.
	std::unordered_map<unsigned, unsigned> binCache;
	//Reserve more space than we need (probably), because not every pixel will have a cache entry.
	binCache.reserve(pixelCount * checkPercentage);
	
	NSLog(@"Starting sorting pixels at %f.", CACurrentMediaTime());
	const CFTimeInterval pixelSortStart = CACurrentMediaTime();
	
	const unsigned long actualInterval = (pixelCount / (pixelCount * checkPercentage)) * 4;
	for(unsigned long pixel = 0; pixel < length; pixel += actualInterval) {
		//These variables will hold the current closest known bin and the distance between that bin's colour and the pixel's colour.
		unsigned bestBin = 0;
		double bestDistance = DBL_MAX;
		
		//Pixel colour values.
		const unsigned char pixelRed = pixelBuffer[pixel];
		const unsigned char pixelGreen = pixelBuffer[pixel + 1];
		const unsigned char pixelBlue = pixelBuffer[pixel + 2];
		
		//Skip if the alpha is 0.
		if(pixelBuffer[pixel + 3] == 0) continue;
		
		//Check if the cache has this pixel colour in it.
		const unsigned fullRGB = (pixelRed << 16) | (pixelGreen << 8) | (pixelBlue << 0);
		if(binCache.count(fullRGB) > 0) {
			//It does, so we can just use the cached value and continue to the next pixel.
			bins[binCache[fullRGB]].push_back(fullRGB);
			continue;
		}
		
		const bool halfwayOrOver = pixel >= length / 2;
		for(const auto &colorBin : bins) {
			//If we're at/past halfway and this bin has 0 pixels, risk skipping this bin.
			//This could (in some rare instances) cause a loss of accuracy, but should give a huge performance gain in many images.
			//TODO: Check if a dominant colour is already emerging and only skip if that colour cannot be beaten.
			if(halfwayOrOver && colorBin.second.size() < 1) {
				continue;
			}
			
			//This bin's colour values.
			const unsigned char binRed = (colorBin.first >> 16) & 0xFF;
			const unsigned char binGreen = (colorBin.first >> 8) & 0xFF;
			const unsigned char binBlue = colorBin.first & 0xFF;
			
			//Calculate the distance between the bin and the pixel.
			const double distance = calculateDistance(pixelRed, pixelGreen, pixelBlue, binRed, binGreen, binBlue);
			
			//If this bin's colour is closer to the pixel than the current best's colour, replace the current best with this bin.
			if(distance < bestDistance) {
				bestBin = colorBin.first;
				bestDistance = distance;
				
				//If the distance is 0 (i.e. the pixel and bin are the same colour EXACTLY), we can stop here. Nothing can get closer.
				if(distance == 0) {
					printf("SPEED BOOST! Found exact colour match.\n");
					break;
				}
			}
		}
		
		//Add this pixel colour to the cache to save time later.
		binCache[fullRGB] = bestBin;
		
		//Add one to the chosen bin's count. This increases the dominance.
		bins[bestBin].push_back(fullRGB);
	}
	const CFTimeInterval pixelSortEnd = CACurrentMediaTime();
	NSLog(@"Finished sorting pixels at %f; took %f seconds.", pixelSortEnd, pixelSortEnd - pixelSortStart);
	CFRelease(pixelData);
	NSLog(@"Pixel processing speed = %.0f/sec", (length / actualInterval) / (pixelSortEnd - pixelSortStart));
	
	const CFTimeInterval finalColorDecisionStart = CACurrentMediaTime();
	NSLog(@"Starting final decision making at %f.", finalColorDecisionStart);
	
	//Sort the bins by their count and get the first entry.
	auto sorted = sortBins(bins);
	
	auto dominantBin = sorted[0];

	if(generateColorListOnly) {
		lastColorBins.clear();

		for(unsigned i = 0; i < sorted.size(); ++i) {
			const std::pair<unsigned, std::vector<unsigned>> binPair = sorted[i];
			
			//Make sure this colour is worth considering by checking if the colour accounts for vibrancyIgnorePercentage of the pixels we checked.
			//A threshold of about 0.003 (0.3%) tends to work well.
			static unsigned pixelsChecked = pixelCount / (pixelCount * checkPercentage);
			if(binPair.second.size() < vibrancyIgnorePercentage * pixelsChecked) {
				//Less than the specified amount, so stop checking.
				break;
			}
			
			//Get the RGB values.
			const unsigned char red = (binPair.first >> 16) & 0xFF;
			const unsigned char green = (binPair.first >> 8) & 0xFF;
			const unsigned char blue = (binPair.first >> 0) & 0xFF;

			lastColorBins.push_back([UIColor colorWithRed:float(red) / 255.f green:float(green) / 255.f blue:float(blue) / 255.f alpha:1.f]);
		}

		return nullptr;
	}

	//If we are supposed to be looking for vibrant colours (i.e. avoiding white and black and instead pick out colourful stuff), we need to do that now.
	if(seekVibrant) {
		/*
		 Vibrancy (in this context):
		 let a be RGB(x, y, z)
		 let b be (x + y + z) / 3
		 let c be distance(a, RGB(b, b, b))
		 
		 if c > 50:
		 a is vibrant
		 else:
		 a is dull
		 
		 This works fairly well because colours with similar r, g and b values are much more boring. You can see this if you go to https://www.google.com/search?q=color+picker
		 and move the picker circle down the left or along the bottom.
		 
		 //you don't understand how proud of myself i am to have worked that out lol
		 */
		
		for(unsigned i = 0; i < sorted.size(); ++i) {
			const std::pair<unsigned, std::vector<unsigned>> binPair = sorted[i];
			
			//Make sure this colour is worth considering by checking if the colour accounts for vibrancyIgnorePercentage of the pixels we checked.
			//A threshold of about 0.003 (0.3%) tends to work well.
			static unsigned pixelsChecked = pixelCount / (pixelCount * checkPercentage);
			if(binPair.second.size() < vibrancyIgnorePercentage * pixelsChecked) {
				//Less than the specified amount, so stop checking.
				break;
			}
			
			//Get the RGB values.
			const unsigned char red = (binPair.first >> 16) & 0xFF;
			const unsigned char green = (binPair.first >> 8) & 0xFF;
			const unsigned char blue = (binPair.first >> 0) & 0xFF;
			
			//Get the distance between this colour and its average.
			const unsigned char rgbAverage = (red + green + blue) / 3;
			
			const double averageDistance = calculateDistance(red, green, blue, rgbAverage, rgbAverage, rgbAverage);
			if(averageDistance > 50.0f) {
				//This is a vibrant colour.
				dominantBin = binPair;
				break;
			}
		}
	}
	
	printf("Dominant:\n");
	for(unsigned i = 0; i < sorted.size() && i < 10; ++i) {
		printf("%d: Colour = RGB(%u, %u, %u), Count = %lu\n", i, (sorted[i].first >> 16) & 0xFF, (sorted[i].first >> 8) & 0xFF, (sorted[i].first >> 0) & 0xFF, sorted[i].second.size());
	}
	
	//Get the average colour from the dominant bin. This helps increase accuracy.
	unsigned long totalRed = 0, totalGreen = 0, totalBlue = 0;
	for(const unsigned &binPixel : dominantBin.second) {
		totalRed += (binPixel >> 16) & 0xFF;
		totalGreen += (binPixel >> 8) & 0xFF;
		totalBlue += binPixel & 0xFF;
	}
	
	const CFTimeInterval finalColorDecisionEnd = CACurrentMediaTime();
	NSLog(@"Finished final decision making at %f; took %f seconds.", finalColorDecisionEnd, finalColorDecisionEnd - finalColorDecisionStart);
	
	NSLog(@"********** Full time: %f **********", finalColorDecisionEnd - binStart);
	auto ret = [UIColor colorWithRed:totalRed / dominantBin.second.size() / 255.0f green:totalGreen / dominantBin.second.size() / 255.0f blue:totalBlue / dominantBin.second.size() / 255.0f alpha:1.0f];
    NSLog(@"ret = %@", ret);
    return ret;
}

inline UIColor *foregroundColor(UIColor *col) {
	CGFloat r, g, b, a;
	[col getRed:&r green:&g blue:&b alpha:&a];

	r *= 255.f;
	g *= 255.f;
	b *= 255.f;

	return 255.f - (r * .299f + g * .587f + b * .114f) < 105.f ? [UIColor blackColor] : [UIColor whiteColor];
}

inline UIColor *colorFromDefaults(NSString *key, NSString *domain, UIColor *defaultColor) {
	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:domain];
	NSNumber *colorValue = [defaults objectForKey:key];

	//If the colour wasn't found, return the default colour.
	if(!colorValue) return defaultColor;

	const unsigned colorInt = [colorValue unsignedIntegerValue];

	//Get the different colour components.
	const unsigned r = colorInt >> 24 & 0xFF,
	             g = colorInt >> 16 & 0xFF,
	             b = colorInt >> 8  & 0xFF,
	             a = colorInt >> 0  & 0xFF;

	return [UIColor colorWithRed:r / 255.0f green:g / 255.0f blue:b / 255.0f alpha:a / 100.0f];
}

@implementation UIColor (LightAndDark)

- (UIColor *)lighterColor {
    CGFloat h, s, b, a;
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a])
        return [UIColor colorWithHue:h
                          saturation:s
                          brightness:MIN(b * 1.3, 1.0)
                               alpha:a];
    return nil;
}

- (UIColor *)darkerColor {
    CGFloat h, s, b, a;
    if ([self getHue:&h saturation:&s brightness:&b alpha:&a])
        return [UIColor colorWithHue:h
                          saturation:s
                          brightness:b * 0.75
                               alpha:a];
    return nil;
}
@end