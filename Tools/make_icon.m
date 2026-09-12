#import <Cocoa/Cocoa.h>

static void DrawIcon(CGFloat size, NSString *path) {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(size, size)];
    [image lockFocus];

    NSRect bounds = NSMakeRect(0, 0, size, size);
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:size * 0.18 yRadius:size * 0.18];
    [[NSColor colorWithCalibratedRed:0.08 green:0.43 blue:0.72 alpha:1] setFill];
    [background fill];

    NSBezierPath *left = [NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, size * 0.5, size)];
    [[NSColor colorWithCalibratedRed:0.05 green:0.53 blue:0.39 alpha:1] setFill];
    [left fill];

    NSDictionary *standAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:size * 0.46 weight:NSFontWeightBlack],
        NSForegroundColorAttributeName: NSColor.whiteColor
    };
    NSDictionary *waterAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:size * 0.32 weight:NSFontWeightHeavy],
        NSForegroundColorAttributeName: NSColor.whiteColor
    };

    NSString *stand = @"站";
    NSString *water = @"水";
    NSSize standSize = [stand sizeWithAttributes:standAttrs];
    NSSize waterSize = [water sizeWithAttributes:waterAttrs];
    [stand drawAtPoint:NSMakePoint(size * 0.25 - standSize.width / 2, size * 0.55 - standSize.height / 2) withAttributes:standAttrs];
    [water drawAtPoint:NSMakePoint(size * 0.72 - waterSize.width / 2, size * 0.38 - waterSize.height / 2) withAttributes:waterAttrs];

    [image unlockFocus];

    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    rep.size = NSMakeSize(size, size);
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [png writeToFile:path atomically:YES];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: make_icon <iconset-dir>\n");
            return 1;
        }

        NSString *dir = [NSString stringWithUTF8String:argv[1]];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];

        NSDictionary<NSString *, NSNumber *> *sizes = @{
            @"icon_16x16.png": @16,
            @"icon_16x16@2x.png": @32,
            @"icon_32x32.png": @32,
            @"icon_32x32@2x.png": @64,
            @"icon_128x128.png": @128,
            @"icon_128x128@2x.png": @256,
            @"icon_256x256.png": @256,
            @"icon_256x256@2x.png": @512,
            @"icon_512x512.png": @512,
            @"icon_512x512@2x.png": @1024
        };

        for (NSString *name in sizes) {
            DrawIcon(sizes[name].doubleValue, [dir stringByAppendingPathComponent:name]);
        }
    }
    return 0;
}
